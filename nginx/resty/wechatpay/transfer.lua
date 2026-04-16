
-- 商家转账
-- https://pay.weixin.qq.com/doc/v3/merchant/4012711988

-- 企业赔付
-- https://pay.weixin.qq.com/doc/v3/merchant/4013774589

-- 普通商户
-- https://pay.weixin.qq.com/doc/v3/merchant/4012716434

local wechatpay = require "resty.wechatpay"
local cjson     = require "cjson.safe"
local _gsub     = string.gsub

local _T = {}
local __ = { ver = "v26.04.14", types = _T }

-- 清除字符串头尾空白符，如果结果是空字符串则返回 nil
local _strip = function(s)
-- @s       : string
-- @return  : string?

    if type(s) ~= "string" or s == "" then
        return nil
    end

    s = _gsub(s, "^%s*(.-)%s*$", "%1")
    if s == "" then return nil end

    return s

end

_T.TransferSenceInfo = {
    info_type       = "//信息类型: 不能超过15个字符，商户所属转账场景下的信息类型，此字段内容为固定值，需严格按照转账场景报备信息字段说明传参。",
    info_content    = "//信息内容: 不能超过32个字符，商户所属转账场景下的信息内容，商户可按实际业务场景自定义传参，需严格按照转账场景报备信息字段说明传参。"
}
_T.CreateReq = {
    appid                       = "//商户AppID: 微信开放平台和微信公众平台为开发者的应用程序(APP、小程序、公众号、企业号corpid即为此AppID)提供的一个唯一标识。此处，可以填写这四种类型中的任意一种APPID，但请确保该appid与商户号有绑定关系",
    out_bill_no                 = "//商户单号: 商户系统内部的商家单号，要求此参数只能由数字、大小写字母组成，在商户系统内部唯一",
    transfer_scene_id           = "//转账场景ID: 该笔转账使用的转账场景，可前往“商户平台-产品中心-商家转账”中申请",
    openid                      = "//收款用户OpenID: 用户在商户appid下的唯一标识。发起转账前需获取到用户的OpenID",
    user_name                   = "?//收款用户姓名: 收款方真实姓名。若传入收款用户姓名，微信支付会校验收款用户与输入姓名是否一致。转账金额>=2,000元时，必须传入该值。该字段需要加密传入",
    transfer_amount             = "number//转账金额: 转账金额，单位为“分”，最低为 0.1 元",
    transfer_remark             = "//转账备注: 转账备注，用户收款时可见该备注信息，UTF8编码，最多允许32个字符",
    notify_url                  = "?//通知地址: 异步接收微信支付结果通知的回调地址，通知url必须为公网可访问的URL，必须为HTTPS，不能携带参数",
    user_recv_perception        = "?//用户收款感知: 用户收款时感知的收款原因。不填或填空，将展示转账场景的默认内容。",
    transfer_scene_report_infos = "@TransferSenceInfo[]//转账场景报备信息: 需按转账场景准确填写报备信息",
}
_T.CreateRes = {
    out_bill_no         = "//商户单号: 商户系统内部的商家单号，要求此参数只能由数字、大小写字母组成，在商户系统内部唯一",
    transfer_bill_no    = "//微信转账单号: 微信转账单号，微信商家转账系统返回的唯一标识",
    create_time         = "//单据创建时间: 单据受理成功时返回，按照使用rfc3339所定义的格式，格式为yyyy-MM-DDThh:mm:ss+TIMEZONE",
    state               = [[//单据状态: 商家转账订单状态
* ACCEPTED:  转账已受理，可原单重试（非终态）。
* PROCESSING:  转账锁定资金中。如果一直停留在该状态，建议检查账户余额是否足够，如余额不足，可充值后再原单重试（非终态）。
* WAIT_USER_CONFIRM:  待收款用户确认，当前转账单据资金已锁定，可拉起微信收款确认页面进行收款确认（非终态）。
* TRANSFERING:  转账中，可拉起微信收款确认页面再次重试确认收款（非终态）。
* SUCCESS:  转账成功，表示转账单据已成功（终态）。
* FAIL:  转账失败，表示该笔转账单据已失败。若需重新向用户转账，请重新生成单据并再次发起（终态）。
* CANCELING:  转账撤销中，商户撤销请求受理成功，该笔转账正在撤销中，需查单确认撤销的转账单据状态（非终态）。
* CANCELLED:  转账撤销完成，代表转账单据已撤销成功（终态）。
]]
}
__.create__ = {
    "发起转账",
--  https://pay.weixin.qq.com/doc/v3/merchant/4012716434
    req = "@CreateReq",
    res = "@CreateRes",
}
__.create = function(t)

    -- 企业赔付  : 转账场景ID为 1011
    -- info_type : 企业赔付，固定为 赔付原因

    t.user_name = _strip(t.user_name)
    if t.user_name then
        t.user_name = wechatpay.utils.encrypt(t.user_name)  -- 敏感信息加密
    end

    local res, err = wechatpay.utils.request {
        url  = "/v3/fund-app/mch-transfer/transfer-bills",
        body = cjson.encode(t)
    }
    if not res then return nil, err end

    return res

end

_T.CancelRes = {
    out_bill_no      = "//商户单号:  商户系统内部的商家单号，要求此参数只能由数字、大小写字母组成，在商户系统内部唯一",
    transfer_bill_no = "//微信转账单号: 商家转账订单的主键，唯一定义此资源的标识",
    state            = "//单据状态:  CANCELING: 撤销中；CANCELLED:已撤销",
    update_time      = "//最后一次单据状态变更时间: 按照使用rfc3339所定义的格式，格式为yyyy-MM-DDThh:mm:ss+TIMEZONE",
}
__.cancel__ = {
    "撤销转账",
--  https://pay.weixin.qq.com/doc/v3/merchant/4012716458
    req = {
        { "out_bill_no" , "商户单号" },
    },
    res = "@CancelRes",
}
__.cancel = function(t)

    local url = "/v3/fund-app/mch-transfer/transfer-bills/out-bill-no/{out_bill_no}/cancel"
          url = url:gsub("{out_bill_no}", t.out_bill_no)

    return wechatpay.utils.request { url = url, body = "" }  -- 【坑】body需要传递空字符串，否则报405错误

end

_T.QueryRes = {
    mch_id           = "//商户号: 微信支付分配的商户号",
    out_bill_no      = "//商户单号: 商户系统内部的商家单号，要求此参数只能由数字、大小写字母组成，在商户系统内部唯一",
    transfer_bill_no = "//商家转账订单号: 商家转账订单的主键，唯一定义此资源的标识",
    appid            = "//商户AppID: 是微信开放平台和微信公众平台为开发者的应用程序(APP、小程序、公众号、企业号corpid即为此AppID)提供的一个唯一标识。此处，可以填写这四种类型中的任意一种APPID，但请确保该appid与商户号有绑定关系。",
    state            = [[//单据状态: 商家转账订单状态
* ACCEPTED:  转账已受理，可原单重试（非终态）。
* PROCESSING:  转账锁定资金中。如果一直停留在该状态，建议检查账户余额是否足够，如余额不足，可充值后再原单重试（非终态）。
* WAIT_USER_CONFIRM:  待收款用户确认，当前转账单据资金已锁定，可拉起微信收款确认页面进行收款确认（非终态）。
* TRANSFERING:  转账中，可拉起微信收款确认页面再次重试确认收款（非终态）。
* SUCCESS:  转账成功，表示转账单据已成功（终态）。
* FAIL:  转账失败，表示该笔转账单据已失败。若需重新向用户转账，请重新生成单据并再次发起（终态）。
* CANCELING:  转账撤销中，商户撤销请求受理成功，该笔转账正在撤销中，需查单确认撤销的转账单据状态（非终态）。
* CANCELLED:  转账撤销完成，代表转账单据已撤销成功（终态）。
]],
    transfer_amount  = "number//转账金额: 转账金额单位为“分”。",
    transfer_remark  = "//转账备注: 单条转账备注（微信用户会收到该备注），UTF8编码，最多允许32个字符",
    fail_reason      = "?//失败原因: 订单已失败或者已退资金时，会返回订单失败原因",
    openid           = "?//收款用户OpenID: 用户在商户appid下的唯一标识。发起转账前需获取到用户的OpenID",
    user_name        = "?//收款用户姓名: 收款方真实姓名。若商户在发起转账时传入了收款用户姓名，则查询接口中会返回，并提供电子回单。字段解密",
    create_time      = "//单据创建时间: 单据受理成功时返回，按照使用rfc3339所定义的格式，格式为yyyy-MM-DDThh:mm:ss+TIMEZONE",
    update_time      = "//最后一次状态变更时间: 单据最后更新时间，按照使用rfc3339所定义的格式，格式为yyyy-MM-DDThh:mm:ss+TIMEZONE"
}

__.query__ = {
    "查询订单",
--  https://pay.weixin.qq.com/doc/v3/merchant/4012716437
--  https://pay.weixin.qq.com/doc/v3/merchant/4012716457
    req = {
        { "out_bill_no?"        , "商户单号"        },
        { "transfer_bill_no?"   , "微信转账单号"    },
    },
    res = "@QueryRes"
}
__.query = function(t)

    t.out_bill_no       = _strip(t.out_bill_no)
    t.transfer_bill_no  = _strip(t.transfer_bill_no)

    if not t.out_bill_no and not t.transfer_bill_no then
        return nil, "商户单号或微信转账单号不能为空"
    end

    local url
    if t.out_bill_no then
        url = "/v3/fund-app/mch-transfer/transfer-bills/out-bill-no/" .. t.out_bill_no
    elseif t.transfer_bill_no then
        url = "/v3/fund-app/mch-transfer/transfer-bills/transfer-bill-no/" .. t.transfer_bill_no
    end

    return wechatpay.utils.request { url = url }

end

return __
