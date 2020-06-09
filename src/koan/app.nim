
type
  App* = ref object of RootObj
    proxy*: bool
    subdomainOffset*: int
    proxyIpHeader*: string
    maxIpsCount*: int
    env*: string
