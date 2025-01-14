targetScope = 'subscription'

/////// VARS (defined in 'params.json') ////////
param clientVar object
param vnetVar object
param vmVar object
param sshK string = loadTextContent('./etc/SSHKey.pub')
param kvVar object = {
  location: clientVar.location
  objectId: clientVar.objId
  tenantId: tenantId
  kvName: kvName
}
param tagsC object ={
    Client:clientVar.client
    Version:'1.0'
    DeployDate:utcNow('d')
    Time:utcNow('T')
}
@secure()
param privIp string
@secure()
param pwdWin string
param recVltName string = 'rv${toLower(uniqueString(utcNow()))}'
param tenantId string = subscription().tenantId
param kvName string = '${clientVar.client}-KV-${toLower(uniqueString(utcNow()))}'
param stgName string = 'storage${toLower(uniqueString(utcNow()))}'

/////////// CREATE RESOURCE GROUP ////////////
resource resGr 'Microsoft.Resources/resourceGroups@2021-04-01' = {
  name: clientVar.rgName
  location: clientVar.location
  tags:tagsC
}
///////////  CREATE VNET   ///////////////////
module vnet './module/mod-vnet.bicep' = {
  scope: resGr
  name: '${clientVar.client}-vnet'
  params:{
    privIp: privIp
    tags: tagsC
    vnetVar: vnetVar
    clientVar: clientVar
  }
}

/////////// CREATE KEYVAULT //////////////////
module kv './module/mod-kv.bicep' = {
  scope: resGr
  name: kvName
  params:{
    vnetVar: vnetVar
    tags: tagsC
    clientVar: clientVar
    kvVar: kvVar
    subId1: vnet.outputs.subnetId1
    subId2: vnet.outputs.subnetId2
  }
  dependsOn: [
    vnet
  ]
}
///////////// CREATE STORAGE //////////////////
module stg './module/mod-stg.bicep' = {
  scope: resGr
  name: stgName 
  params:{
    tags: tagsC
    mngId: kv.outputs.mngId
    clientVar: clientVar
    stgType: vmVar.stgType
    stgName: stgName
    subId1: vnet.outputs.subnetId1
    subId2: vnet.outputs.subnetId2
    kvUri: kv.outputs.kvUri
  }
  dependsOn: [
    kv
    vnet
  ]
}

//////////// DEPLOY VM'S ////////////////
module vm './module/mod-vm.bicep' = {
  scope: resGr
  name: 'vm'
  params:{
    tags: tagsC
    dskEncrKey: kv.outputs.dskEncrId
    clientVar: clientVar
    vmVar: vmVar
    sshK: sshK
    pip1: vnet.outputs.pubId1
    pip2: vnet.outputs.pubId2
    subId1: vnet.outputs.subnetId1
    subId2: vnet.outputs.subnetId2
    pwdWin: pwdWin
  }
  dependsOn:[
    stg
    vnet
    kv
  ]
}
/////////////  BACKUP  ////////////////////
module rv './module/mod-rv.bicep' = {
  scope: resGr
  name: recVltName
  params: {
    recVltName: recVltName
    //mngName: kv.outputs.mngName
    admSrvName: vm.outputs.admSrvName
    webSrvName: vm.outputs.webSrvName
    tags: tagsC
    //kvUri: kv.outputs.kvUri
    clientVar: clientVar
    webVmId: vm.outputs.webVmId
    admVmId: vm.outputs.admVmId
  }
  dependsOn:[
    vm
  ]
}

