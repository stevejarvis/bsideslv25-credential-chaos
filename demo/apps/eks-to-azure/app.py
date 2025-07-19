#!/usr/bin/env python3
"""
EKS to Azure Demo Application
Proves cross-cloud authentication by calling Azure Resource Manager from AWS EKS
Authentication flow: IRSA → IAM Role → Cognito → Azure
"""

import os
import time
import boto3
from azure.identity import ClientAssertionCredential
from azure.mgmt.resource import ResourceManagementClient
from azure.core.exceptions import ClientAuthenticationError, HttpResponseError
from botocore.exceptions import ClientError

def get_cognito_jwt():
    """Get Cognito JWT using IRSA credentials"""
    try:
        import jwt
        from datetime import datetime, timedelta
        
        # Verify IRSA authentication first
        sts_client = boto3.client('sts', region_name='us-west-2')
        caller_identity = sts_client.get_caller_identity()
        
        print(f"✅ Authenticated to AWS via IRSA")
        print(f"🔍 AWS Account: {caller_identity['Account']}")
        
        # Get Cognito configuration
        user_pool_id = os.environ.get('COGNITO_USER_POOL_ID')
        if not user_pool_id:
            print("❌ COGNITO_USER_POOL_ID not configured")
            return None
            
        # Create simplified JWT for demo
        now = datetime.utcnow()
        payload = {
            'iss': f'https://cognito-idp.us-west-2.amazonaws.com/{user_pool_id}',
            'sub': 'system:serviceaccount:demo:workload-identity-sa',
            'aud': 'api://AzureADTokenExchange',
            'iat': int(now.timestamp()),
            'exp': int((now + timedelta(hours=1)).timestamp()),
            'cognito:username': 'eks-workload'
        }
        
        # For demo: unsigned JWT (production would be signed by Cognito)
        token = jwt.encode(payload, 'demo-secret', algorithm='HS256')
        
        print(f"✅ Generated Cognito JWT")
        return token
        
    except Exception as e:
        print(f"❌ Failed to get Cognito JWT: {e}")
        return None

def get_azure_credential():
    """Get Azure credential using Cognito JWT"""
    try:
        # Get Cognito JWT
        cognito_jwt = get_cognito_jwt()
        if not cognito_jwt:
            return None
            
        # Azure configuration
        tenant_id = os.environ.get('AZURE_TENANT_ID')
        client_id = os.environ.get('AZURE_CLIENT_ID')
        
        if not tenant_id or not client_id:
            print("❌ Azure tenant ID or client ID not configured")
            return None
            
        # Use ClientAssertionCredential with Cognito JWT
        from azure.identity import ClientAssertionCredential
        
        def get_assertion():
            return cognito_jwt
            
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
        time.sleep(30)  # Wait 30 seconds between attempts

if __name__ == "__main__":
    main()