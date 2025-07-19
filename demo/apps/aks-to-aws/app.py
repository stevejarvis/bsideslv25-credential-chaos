#!/usr/bin/env python3
"""
AKS to AWS Demo Application
Proves cross-cloud authentication by calling AWS STS from Azure AKS
"""

import os
import sys
import time
import json
import boto3
from azure.identity import DefaultAzureCredential
from botocore.exceptions import ClientError, NoCredentialsError

def get_entra_jwt():
    """Get Entra ID JWT using Workload Identity"""
    try:
        credential = DefaultAzureCredential()
        
        # Get Entra ID token with proper AWS scope (/.default suffix required for client credentials flow)
        token = credential.get_token("api://AzureADTokenExchange/.default")
        
        print(f"✅ Got Entra ID JWT via Workload Identity")
        return token.token
        
    except Exception as e:
        print(f"❌ Failed to get Entra JWT: {e}")
        return None

def assume_aws_role():
    """Assume AWS IAM role using Entra ID JWT"""
    try:
        entra_jwt = get_entra_jwt()
        if not entra_jwt:
            return None
            
        sts_client = boto3.client('sts', region_name='us-west-2')
        role_arn = os.environ.get('AWS_ROLE_ARN')
        
        if not role_arn:
            print("❌ AWS_ROLE_ARN not configured")
            return None
            
        response = sts_client.assume_role_with_web_identity(
            RoleArn=role_arn,
            RoleSessionName='AKSWorkloadSession',
            WebIdentityToken=entra_jwt
        )
        
        print(f"✅ Assumed AWS role via Entra ID JWT")
        return response['Credentials']
        
    except ClientError as e:
        print(f"❌ Failed to assume AWS role: {e}")
        return None

def call_aws_sts():
    """Call AWS STS get-caller-identity to prove authentication"""
    try:
        # Assume AWS role
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
        
        # Get caller identity
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
    print("🔗 Flow: AKS Workload ID → Entra ID JWT → AWS IAM Role")
    print("=" * 50)
    
    # Check environment
    pod_name = os.environ.get('HOSTNAME', 'unknown')
    namespace = os.environ.get('POD_NAMESPACE', 'unknown')
    
    print(f"📍 Running in AKS pod: {pod_name}")
    print(f"🌐 Namespace: {namespace}")
    print()
    
    # Continuous authentication test
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
        time.sleep(30)  # Wait 30 seconds between attempts

if __name__ == "__main__":
    main()