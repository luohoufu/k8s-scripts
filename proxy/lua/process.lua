local print = ngx.print
local cjson = require("cjson.safe")

local args = ngx.req.get_uri_args()
local method = args["method"]
local data = args["data"]
local callback = args["callback"]
local extra1 = args["extra1"]
local extra2 = args["extra2"]

cjson.encode_empty_table_as_object(false)

--组合用户信息与购物车数量
if extra1 == 'cart_count' then
   local body = ngx.encode_args({data=data,request_id=RequestId()})
   local dispatch_url = Dispatch(method)
   local res1 = ngx.location.capture("/proxy",{ method = ngx.HTTP_POST,body = body,vars = {dispatch = dispatch_url}})

   if res1.status ~= 200 then
      return print(Err(err_103))
   end

   local res1_body = cjson.decode(res1.body)
   if res1_body and res1_body.code ~= 1 then
     if callback == nil then
      return print(res1.body)
     end
     return print(callback.."("..res1.body..")")
   end

   local data1={}
   data1['ukey'] = res1_body.data.ukey
   data1['from_device'] = 'pc'
   local body1 = ngx.encode_args({data=cjson.encode(data1),request_id=RequestId()})
   local dispatch_url1 = Dispatch(extra1)
   local res2 = ngx.location.capture("/proxy",{ method = ngx.HTTP_POST,body = body1,vars = {dispatch = dispatch_url1}})
   if res2.status == 200 then
     local res2_body = cjson.decode(res2.body)
     if res2_body and res2_body.code == 1 then
       res1_body.data.cartCount = res2_body.data.count
     end
   end
   local res = cjson.encode(res1_body)
   if callback == nil then
      return print(res)
   end
   return print(callback.."("..res..")")
end

--组合端口详情与收藏与评论
if extra1 == 'get_product_praises' and extra2 == 'get_top_comment' then
   local req_id = RequestId()
   local req_data = cjson.decode(data)

   if req_data == nil then
       return print(Err(err_105))
   end

   local req1_data={}
   req1_data['ukey']=req_data['ukey']
   req1_data['productId']=req_data['product_id']

   local req2_data={}
   req2_data['objType']=1
   req2_data['objId']=req_data['product_id']

   local main_body = ngx.encode_args({data=data,request_id=req_id})
   local extra1_body = ngx.encode_args({data=cjson.encode(req1_data),request_id=req_id})
   local extra2_body = ngx.encode_args({data=cjson.encode(req2_data),request_id=req_id})

   local main_url = Dispatch(method)
   local extra1_url = Dispatch(extra1)
   local extra2_url = Dispatch(extra2)

   local res1, res2, res3 = ngx.location.capture_multi{
      { "/proxy", {method = ngx.HTTP_POST,body = main_body,vars = {dispatch = main_url}} },
      { "/proxy", {method = ngx.HTTP_POST,body = extra1_body,vars = {dispatch = extra1_url}} },
      { "/proxy", {method = ngx.HTTP_POST,body = extra2_body,vars = {dispatch = extra2_url}} },
   }

   if res1.status ~= 200 then
      return print(Err(err_103))
   end

   local res1_body = cjson.decode(res1.body)
   if res1_body and res1_body ~= ngx.null and res1_body.code ~= 1 then
     if callback == nil then
      return print(res1.body)
     end
     return print(callback.."("..res1.body..")")
   end

   if res2.status == 200 and res1_body ~= ngx.null then
     local res2_body = cjson.decode(res2.body)
     res1_body.data.response_product_get.field_praise = res2_body.data
   end
   if res3.status == 200 and res1_body ~= ngx.null then
     local res3_body = cjson.decode(res3.body)
     res1_body.data.response_product_get.field_comment = res3_body.data
   end
   local res = cjson.encode(res1_body)
   if callback == nil then
      return print(res)
   end
   return print(callback.."("..res..")")
end
