local len = string.len
local upper = string.upper
local sub = string.sub
local print = ngx.print

--图片上传处理
local content_type = ngx.var.content_type
if content_type ~= nil and len(content_type)>20 and sub(content_type,1,20)=="multipart/form-data;" then
   ngx.var.dispatch = Dispatch("upload_image")
   return ngx.exec("/upload")
end

--获取参数的值
local request_method = ngx.var.request_method
if "GET" == request_method then
   args = ngx.req.get_uri_args()
elseif "POST" == request_method then
   ngx.req.read_body()
   args = ngx.req.get_post_args()
else
   return print(Err(err_103))
end

local appkey = args["appkey"]
local version = args["v"]
local data = args["data"]
local method = args["method"]
local timestamp = args["timestamp"]
local sign = args["sign"]
local callback = args["callback"]

--不符合参数要求
if appkey == nil or method == nil or version == nil or data == nil then
   return print(Err(err_105))
end

--APPKEY不存在
local secret_key = SecretKey(appkey)
if secret_key == nil then
   return print(Err(err_100))
end

--鉴权失败
if secret_key ~= "" then
   if timestamp == nil then
        return print(Err(err_105))
   end
   local sign_data = appkey..method..version..data..secret_key..timestamp
   local check_sign = ngx.md5(sign_data)
   if check_sign ==nil or upper(check_sign) ~= sign then
      return print(Err(err_101))
   end
end

--请求URL不存在
local dispatch_url = Dispatch(method)
if dispatch_url == nil then
   return print(Err(err_104))
end

--设置请求头和响应头
ngx.req.set_header("Content-Type", "application/x-www-form-urlencoded")
ngx.req.set_header("apiVersion",version)

--路由数据聚合处理
local route_url = process:get(method)
if route_url ~= nil then
   local local_url = route_url..'&method='..method..'&data='..data
   if callback ~= nil then
      local_url = local_url..'&callback='..callback
   end
   return ngx.exec(local_url)
end

--设置请求数据
local body = ngx.encode_args({method=method,data=data,request_id=RequestId()})
--内部代理跳转
if callback == nil then
   ngx.var.dispatch = dispatch_url
   ngx.req.set_method(ngx.HTTP_POST)
   ngx.req.set_body_data(body)
   return ngx.exec("/proxy")
end

--跨域处理
local res = ngx.location.capture("/proxy",{ method = ngx.HTTP_POST,body = body,vars = {dispatch = dispatch_url}})
if res.status ~= 200 then
   return print(Err(err_103))
end
return print(callback.."("..res.body..")")
