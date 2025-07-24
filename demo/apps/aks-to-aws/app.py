#!/usr/bin/env python3
"""
AKS to AWS Demo Application
Proves cross-cloud authentication by calling AWS STS from Azure AKS
"""

import os
import sys
import time
import json
import base64
import boto3
from botocore.exceptions import ClientError, NoCredentialsError

def decode_jwt_payload(token):
    """Decode JWT payload for inspection (without signature verification)"""
    try:
        parts = token.split('.')
        if len(parts) != 3:
            return None
            
        payload = parts[1]
        # Add padding if needed
        payload += '=' * (4 - len(payload) % 4)
        
        decoded = base64.urlsafe_b64decode(payload)
        return json.loads(decoded)
    except Exception as e:
        print(f"❌ Failed to decode JWT: {e}")
        return None

def get_kubernetes_jwt():
    """Get Kubernetes service account JWT from projected volume"""
    try:
        # Read the projected service account token for AWS STS
        token_path = '/var/run/secrets/kubernetes.io/serviceaccount/token'
        with open(token_path, 'r') as f:
            k8s_jwt = f.read().strip()
        
        print(f"✅ Got Kubernetes service account JWT")
        print(f"Token length: {len(k8s_jwt)}")
        
        # Decode and inspect token claims
        payload = decode_jwt_payload(k8s_jwt)
        if payload:
            print(f"🔍 JWT Claims:")
            print(f"   Issuer (iss): {payload.get('iss', 'N/A')}")
            print(f"   Audience (aud): {payload.get('aud', 'N/A')}")
            print(f"   Subject (sub): {payload.get('sub', 'N/A')}")
        
        return k8s_jwt
        
    except Exception as e:
        print(f"❌ Failed to get Kubernetes JWT: {e}")
        return None

def assume_aws_role():
    """Assume AWS IAM role using Kubernetes service account JWT"""
    try:
        k8s_jwt = get_kubernetes_jwt()
        if not k8s_jwt:
            return None
            
        sts_client = boto3.client('sts', region_name='us-west-2')
        role_arn = os.environ.get('AWS_ROLE_ARN')
        
        if not role_arn:
            print("❌ AWS_ROLE_ARN not configured")
            return None
            
        response = sts_client.assume_role_with_web_identity(
            RoleArn=role_arn,
            RoleSessionName='AKSWorkloadSession',
            WebIdentityToken=k8s_jwt
        )
        
        print(f"✅ Assumed AWS role via Kubernetes service account JWT")
        return response['Credentials']
        
    except ClientError as e:
        print(f"❌ Failed to assume AWS role: {e}")
        return None

def call_aws_sts():
    """Call AWS STS get-caller-identity to prove authentication"""
    try:
        credentials = assume_aws_role()
        if not credentials:
            return False
            
        # Create STS client with temporary credentials
        sts_client = boto3.client(
            'sts',
            region_name='us-west-2',
            aws_access_key_id=credentials['AccessKeyId'],
            aws_secret_access_key=credentials['SecretAccessKey'],
            aws_session_token=credentials['SessionToken']
        )
        
        response = sts_client.get_caller_identity()
        
        print("🎉 SUCCESS! Cross-cloud authentication working!")
        print(f"📊 AWS Account: {response['Account']}")
        print(f"🔐 Assumed Role: {response['Arn']}")
        print(f"👤 User ID: {response['UserId']}")
        
        return True
    except (ClientError, NoCredentialsError) as e:
        print(f"❌ Failed to call AWS STS: {e}")
        return False

def main():
    """Main application loop"""
    print("🚀 AKS to AWS Authentication Demo")
    print("🔗 Flow: AKS OIDC → Kubernetes service account JWT → AWS IAM Role")
    print("=" * 50)
    
    pod_name = os.environ.get('HOSTNAME', 'unknown')
    namespace = os.environ.get('POD_NAMESPACE', 'unknown')
    
    print(f"📍 Running in AKS pod: {pod_name}")
    print(f"🌐 Namespace: {namespace}")
    print()
    
    success_count = 0
    total_count = 0
    
    while True:
        total_count += 1
        print(f"🔄 Attempt {total_count} - {time.strftime('%Y-%m-%d %H:%M:%S')}")
        
        if call_aws_sts():
            success_count += 1
            print(f"✅ Success rate: {success_count}/{total_count} ({success_count/total_count*100:.1f}%)")
        else:
            print(f"❌ Success rate: {success_count}/{total_count} ({success_count/total_count*100:.1f}%)")
        
        print("-" * 50)
        time.sleep(20)  

if __name__ == "__main__":
    main()