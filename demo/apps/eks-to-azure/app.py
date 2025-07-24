#!/usr/bin/env python3
"""
EKS to Azure Demo Application
Proves cross-cloud authentication by calling Azure Resource Manager from AWS EKS
Authentication flow: IRSA → IAM Role → Cognito → Azure
"""

import os
import time
import json
import base64
import boto3
from azure.identity import ClientAssertionCredential
from azure.mgmt.resource import ResourceManagementClient
from azure.core.exceptions import ClientAuthenticationError, HttpResponseError
from botocore.exceptions import ClientError

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

def get_oidc_token_from_identity_pool():
    """Get OIDC token from Cognito Identity Pool using IRSA credentials"""
    try:
        # Verify IRSA authentication first
        sts_client = boto3.client('sts', region_name='us-west-2')
        caller_identity = sts_client.get_caller_identity()
        
        print(f"✅ Authenticated to AWS via IRSA")
        print(f"🔍 AWS Account: {caller_identity['Account']}")
        print(f"🔍 Assumed Role: {caller_identity['Arn']}")
        
        # Get the Identity Pool ID and EKS OIDC issuer from environment
        identity_pool_id = os.environ.get('COGNITO_IDENTITY_POOL_ID')
        eks_oidc_issuer = os.environ.get('EKS_OIDC_ISSUER_URL')
        
        if not identity_pool_id or not eks_oidc_issuer:
            print("❌ COGNITO_IDENTITY_POOL_ID or EKS_OIDC_ISSUER_URL not configured")
            return None
        
        # Read the IRSA token from the projected service account volume
        with open('/var/run/secrets/eks.amazonaws.com/serviceaccount/token', 'r') as f:
            irsa_token = f.read().strip()
        
        print(f"✅ Got IRSA token for Cognito authentication")
        print(f"🔍 EKS OIDC Issuer: {eks_oidc_issuer}")
        
        identity_client = boto3.client('cognito-identity', region_name='us-west-2')
        
        # Call get_id with proper Logins map containing the IRSA token
        eks_oidc_issuer = eks_oidc_issuer.replace('https://', '', 1)
        response = identity_client.get_id(
            IdentityPoolId=identity_pool_id,
            Logins={
                eks_oidc_issuer: irsa_token
            }
        )
        
        identity_id = response['IdentityId']
        print(f"✅ Got Cognito Identity ID: {identity_id}")
        
        # Get the OpenID token with the same Logins map
        token_response = identity_client.get_open_id_token(
            IdentityId=identity_id,
            Logins={
                eks_oidc_issuer: irsa_token
            }
        )
        
        print("✅ Got OIDC token from Identity Pool")
        return token_response['Token']  # This is a JWT
        
    except Exception as e:
        print(f"❌ Failed to get OIDC token from Identity Pool: {e}")
        return None

def get_azure_credential():
    """Get Azure credential using Cognito Identity token"""
    try:
        # Get OIDC token from Cognito Identity Pool
        cognito_token = get_oidc_token_from_identity_pool()
        if not cognito_token:
            return None
            
        # Decode and inspect the real token
        payload = decode_jwt_payload(cognito_token)
        if payload:
            print(f"🔍 Cognito Token Claims:")
            print(f"   Issuer (iss): {payload.get('iss', 'N/A')}")
            print(f"   Audience (aud): {payload.get('aud', 'N/A')}")
            print(f"   Subject (sub): {payload.get('sub', 'N/A')}")
            
        # Azure configuration
        tenant_id = os.environ.get('AZURE_TENANT_ID')
        client_id = os.environ.get('AZURE_CLIENT_ID')
        
        if not tenant_id or not client_id:
            print("❌ Azure tenant ID or client ID not configured")
            return None
            
        # Use ClientAssertionCredential with Cognito JWT
        from azure.identity import ClientAssertionCredential
        
        def get_assertion():
            return cognito_token
            
        credential = ClientAssertionCredential(
            tenant_id=tenant_id,
            client_id=client_id,
            func=get_assertion
        )
        
        print(f"✅ Created Azure credential using Cognito JWT")
        return credential
        
    except Exception as e:
        print(f"❌ Failed to create Azure credential: {e}")
        return None

def call_azure_resource_manager():
    """Call Azure Resource Manager to prove authentication"""
    try:
        # Get Azure credential
        credential = get_azure_credential()
        if not credential:
            return False
            
        # Get subscription ID
        subscription_id = os.environ.get('AZURE_SUBSCRIPTION_ID')
        if not subscription_id:
            print("❌ AZURE_SUBSCRIPTION_ID not configured")
            return False
            
        # Create Resource Management client
        resource_client = ResourceManagementClient(credential, subscription_id)
        
        # List resource groups (simple API call to prove authentication)
        resource_groups = list(resource_client.resource_groups.list())
        
        print("🎉 SUCCESS! Cross-cloud authentication working!")
        print(f"📊 Azure Subscription: {subscription_id}")
        print(f"🏢 Resource Groups Found: {len(resource_groups)}")
        
        # Show first few resource groups
        for i, rg in enumerate(resource_groups[:3]):
            print(f"📁 RG {i+1}: {rg.name} ({rg.location})")
        
        return True
    except (ClientAuthenticationError, HttpResponseError) as e:
        print(f"❌ Failed to call Azure Resource Manager: {e}")
        return False

def main():
    """Main application loop"""
    print("🚀 EKS to Azure Authentication Demo")
    print("🔗 Flow: IRSA → Cognito JWT → Azure Service Principal")
    print("=" * 50)
    
    # Check environment
    pod_name = os.environ.get('HOSTNAME', 'unknown')
    namespace = os.environ.get('POD_NAMESPACE', 'unknown')
    
    print(f"📍 Running in EKS pod: {pod_name}")
    print(f"🌐 Namespace: {namespace}")
    print()
    
    # Continuous authentication test
    success_count = 0
    total_count = 0
    
    while True:
        total_count += 1
        print(f"🔄 Attempt {total_count} - {time.strftime('%Y-%m-%d %H:%M:%S')}")
        
        if call_azure_resource_manager():
            success_count += 1
            print(f"✅ Success rate: {success_count}/{total_count} ({success_count/total_count*100:.1f}%)")
        else:
            print(f"❌ Success rate: {success_count}/{total_count} ({success_count/total_count*100:.1f}%)")
        
        print("-" * 50)
        time.sleep(20)  

if __name__ == "__main__":
    main()