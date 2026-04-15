#!/bin/bash
# =============================================================================
# test-all-os.sh
#
# Test matrix: 14 OS images x 2 network modes = 28 deployments
# All use default VM size (Standard_D2s_v3), EiT enabled, eastasia region.
# Run these commands one at a time or in batches.
#
# Password used for all: Johnjack1213!
# =============================================================================

# --- Ubuntu 24.04 - Service Endpoint ---
az deployment group create \
  --resource-group rongpuliumanagedfs \
  --template-uri "https://raw.githubusercontent.com/VincentLiu777/vmautomouttest/main/vmmounttemplate-allos.json" \
  --parameters resourcePrefix=u2404se location=eastasia osImage=Ubuntu2404 networkAccessMode=ServiceEndpoint adminPassword='Johnjack1213!'

# --- Ubuntu 24.04 - Private Endpoint ---
az deployment group create \
  --resource-group rongpuliumanagedfs \
  --template-uri "https://raw.githubusercontent.com/VincentLiu777/vmautomouttest/main/vmmounttemplate-allos.json" \
  --parameters resourcePrefix=u2404pe location=eastasia osImage=Ubuntu2404 networkAccessMode=PrivateEndpoint adminPassword='Johnjack1213!'

# --- Ubuntu 22.04 - Service Endpoint ---
az deployment group create \
  --resource-group rongpuliumanagedfs \
  --template-uri "https://raw.githubusercontent.com/VincentLiu777/vmautomouttest/main/vmmounttemplate-allos.json" \
  --parameters resourcePrefix=u2204se location=eastasia osImage=Ubuntu2204 networkAccessMode=ServiceEndpoint authType=sshPublicKey sshPublicKey="$(cat ~/.ssh/id_rsa.pub)"

# --- Ubuntu 22.04 - Private Endpoint ---
az deployment group create \
  --resource-group rongpuliumanagedfs \
  --template-uri "https://raw.githubusercontent.com/VincentLiu777/vmautomouttest/main/vmmounttemplate-allos.json" \
  --parameters resourcePrefix=u2204pe location=eastasia osImage=Ubuntu2204 networkAccessMode=PrivateEndpoint adminPassword='Johnjack1213!'

# --- Ubuntu 20.04 - Service Endpoint ---
az deployment group create \
  --resource-group rongpuliumanagedfs \
  --template-uri "https://raw.githubusercontent.com/VincentLiu777/vmautomouttest/main/vmmounttemplate-allos.json" \
  --parameters resourcePrefix=u2004se location=eastasia osImage=Ubuntu2004 networkAccessMode=ServiceEndpoint adminPassword='Johnjack1213!'

# --- Ubuntu 20.04 - Private Endpoint ---
az deployment group create \
  --resource-group rongpuliumanagedfs \
  --template-uri "https://raw.githubusercontent.com/VincentLiu777/vmautomouttest/main/vmmounttemplate-allos.json" \
  --parameters resourcePrefix=u2004pe location=eastasia osImage=Ubuntu2004 networkAccessMode=PrivateEndpoint adminPassword='Johnjack1213!'

# --- Ubuntu 18.04 - Service Endpoint ---
az deployment group create \
  --resource-group rongpuliumanagedfs \
  --template-uri "https://raw.githubusercontent.com/VincentLiu777/vmautomouttest/main/vmmounttemplate-allos.json" \
  --parameters resourcePrefix=u1804se location=eastasia osImage=Ubuntu1804 networkAccessMode=ServiceEndpoint adminPassword='Johnjack1213!'

# --- Ubuntu 18.04 - Private Endpoint ---
az deployment group create \
  --resource-group rongpuliumanagedfs \
  --template-uri "https://raw.githubusercontent.com/VincentLiu777/vmautomouttest/main/vmmounttemplate-allos.json" \
  --parameters resourcePrefix=u1804pe location=eastasia osImage=Ubuntu1804 networkAccessMode=PrivateEndpoint adminPassword='Johnjack1213!'

# --- RHEL 9 - Service Endpoint ---
az deployment group create \
  --resource-group rongpuliumanagedfs \
  --template-uri "https://raw.githubusercontent.com/VincentLiu777/vmautomouttest/main/vmmounttemplate-allos.json" \
  --parameters resourcePrefix=rhel9se location=eastasia osImage=RHEL9 networkAccessMode=ServiceEndpoint adminPassword='Johnjack1213!'

# --- RHEL 9 - Private Endpoint ---
az deployment group create \
  --resource-group rongpuliumanagedfs \
  --template-uri "https://raw.githubusercontent.com/VincentLiu777/vmautomouttest/main/vmmounttemplate-allos.json" \
  --parameters resourcePrefix=rhel9pe location=eastasia osImage=RHEL9 networkAccessMode=PrivateEndpoint adminPassword='Johnjack1213!'

# --- RHEL 8 - Service Endpoint ---
az deployment group create \
  --resource-group rongpuliumanagedfs \
  --template-uri "https://raw.githubusercontent.com/VincentLiu777/vmautomouttest/main/vmmounttemplate-allos.json" \
  --parameters resourcePrefix=rhel8se location=eastasia osImage=RHEL8 networkAccessMode=ServiceEndpoint adminPassword='Johnjack1213!'

# --- RHEL 8 - Private Endpoint ---
az deployment group create \
  --resource-group rongpuliumanagedfs \
  --template-uri "https://raw.githubusercontent.com/VincentLiu777/vmautomouttest/main/vmmounttemplate-allos.json" \
  --parameters resourcePrefix=rhel8pe location=eastasia osImage=RHEL8 networkAccessMode=PrivateEndpoint adminPassword='Johnjack1213!'

# --- RHEL 7 - REMOVED (EOL, all Azure RHUI repos decommissioned) ---

# --- SLES 15 - Service Endpoint ---
az deployment group create \
  --resource-group rongpuliumanagedfs \
  --template-uri "https://raw.githubusercontent.com/VincentLiu777/vmautomouttest/main/vmmounttemplate-allos.json" \
  --parameters resourcePrefix=sles15se location=eastasia osImage=SLES15 networkAccessMode=ServiceEndpoint adminPassword='Johnjack1213!'

# --- SLES 15 - Private Endpoint ---
az deployment group create \
  --resource-group rongpuliumanagedfs \
  --template-uri "https://raw.githubusercontent.com/VincentLiu777/vmautomouttest/main/vmmounttemplate-allos.json" \
  --parameters resourcePrefix=sles15pe location=eastasia osImage=SLES15 networkAccessMode=PrivateEndpoint adminPassword='Johnjack1213!'

# --- Alma Linux 9 - Service Endpoint ---
az deployment group create \
  --resource-group rongpuliumanagedfs \
  --template-uri "https://raw.githubusercontent.com/VincentLiu777/vmautomouttest/main/vmmounttemplate-allos.json" \
  --parameters resourcePrefix=alma9se location=eastasia osImage=AlmaLinux9 networkAccessMode=ServiceEndpoint adminPassword='Johnjack1213!'

# --- Alma Linux 9 - Private Endpoint ---
az deployment group create \
  --resource-group rongpuliumanagedfs \
  --template-uri "https://raw.githubusercontent.com/VincentLiu777/vmautomouttest/main/vmmounttemplate-allos.json" \
  --parameters resourcePrefix=alma9pe location=eastasia osImage=AlmaLinux9 networkAccessMode=PrivateEndpoint adminPassword='Johnjack1213!'

# --- Alma Linux 8 - Service Endpoint ---
az deployment group create \
  --resource-group rongpuliumanagedfs \
  --template-uri "https://raw.githubusercontent.com/VincentLiu777/vmautomouttest/main/vmmounttemplate-allos.json" \
  --parameters resourcePrefix=alma8se location=eastasia osImage=AlmaLinux8 networkAccessMode=ServiceEndpoint adminPassword='Johnjack1213!'

# --- Alma Linux 8 - Private Endpoint ---
az deployment group create \
  --resource-group rongpuliumanagedfs \
  --template-uri "https://raw.githubusercontent.com/VincentLiu777/vmautomouttest/main/vmmounttemplate-allos.json" \
  --parameters resourcePrefix=alma8pe location=eastasia osImage=AlmaLinux8 networkAccessMode=PrivateEndpoint adminPassword='Johnjack1213!'

# --- Oracle Linux 9 - Service Endpoint ---
az deployment group create \
  --resource-group rongpuliumanagedfs \
  --template-uri "https://raw.githubusercontent.com/VincentLiu777/vmautomouttest/main/vmmounttemplate-allos.json" \
  --parameters resourcePrefix=oracl9se location=eastasia osImage=OracleLinux9 networkAccessMode=ServiceEndpoint adminPassword='Johnjack1213!'

# --- Oracle Linux 9 - Private Endpoint ---
az deployment group create \
  --resource-group rongpuliumanagedfs \
  --template-uri "https://raw.githubusercontent.com/VincentLiu777/vmautomouttest/main/vmmounttemplate-allos.json" \
  --parameters resourcePrefix=oracl9pe location=eastasia osImage=OracleLinux9 networkAccessMode=PrivateEndpoint adminPassword='Johnjack1213!'

# --- Oracle Linux 8 - Service Endpoint ---
az deployment group create \
  --resource-group rongpuliumanagedfs \
  --template-uri "https://raw.githubusercontent.com/VincentLiu777/vmautomouttest/main/vmmounttemplate-allos.json" \
  --parameters resourcePrefix=oracl8se location=eastasia osImage=OracleLinux8 networkAccessMode=ServiceEndpoint adminPassword='Johnjack1213!'

# --- Oracle Linux 8 - Private Endpoint ---
az deployment group create \
  --resource-group rongpuliumanagedfs \
  --template-uri "https://raw.githubusercontent.com/VincentLiu777/vmautomouttest/main/vmmounttemplate-allos.json" \
  --parameters resourcePrefix=oracl8pe location=eastasia osImage=OracleLinux8 networkAccessMode=PrivateEndpoint adminPassword='Johnjack1213!'

# --- Azure Linux 3 - Service Endpoint ---
az deployment group create \
  --resource-group rongpuliumanagedfs \
  --template-uri "https://raw.githubusercontent.com/VincentLiu777/vmautomouttest/main/vmmounttemplate-allos.json" \
  --parameters resourcePrefix=azl3se location=eastasia osImage=AzureLinux3 networkAccessMode=ServiceEndpoint adminPassword='Johnjack1213!'

# --- Azure Linux 3 - Private Endpoint ---
az deployment group create \
  --resource-group rongpuliumanagedfs \
  --template-uri "https://raw.githubusercontent.com/VincentLiu777/vmautomouttest/main/vmmounttemplate-allos.json" \
  --parameters resourcePrefix=azl3pe location=eastasia osImage=AzureLinux3 networkAccessMode=PrivateEndpoint adminPassword='Johnjack1213!'

# --- Azure Linux 2 - Service Endpoint ---
az deployment group create \
  --resource-group rongpuliumanagedfs \
  --template-uri "https://raw.githubusercontent.com/VincentLiu777/vmautomouttest/main/vmmounttemplate-allos.json" \
  --parameters resourcePrefix=azl2se location=eastasia osImage=AzureLinux2 networkAccessMode=ServiceEndpoint adminPassword='Johnjack1213!'

# --- Azure Linux 2 - Private Endpoint ---
az deployment group create \
  --resource-group rongpuliumanagedfs \
  --template-uri "https://raw.githubusercontent.com/VincentLiu777/vmautomouttest/main/vmmounttemplate-allos.json" \
  --parameters resourcePrefix=azl2pe location=eastasia osImage=AzureLinux2 networkAccessMode=PrivateEndpoint adminPassword='Johnjack1213!'

# =============================================================================
# CLEANUP: Delete all test resources when done
# =============================================================================
# az group delete --name rongpuliumanagedfs --yes --no-wait
