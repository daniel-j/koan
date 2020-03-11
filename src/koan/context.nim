
proc `method`*(this: Context): string = return this.request.method

proc originalUrl*(this: Context): string = return this.request.originalUrl
