
-- 含多余参数，报错：请求中含有未在API文档中定义的参数

local table         = table
local math          = math

local wechatpay     = require "resty.wechatpay"
local cjson         = require "cjson.safe"

local __ = { ver = "v24.05.21" }

__.types = {

    StoreInfo = {
        { "id"          , "门店编号"    },
        { "name?"       , "门店名称"    },
        { "area_code?"  , "地区编码"    },
        { "address?"    , "详细地址"    },
    },
    H5Info = {
        { "type"            , "场景类型"                },
        { "app_name?"       , "应用名称"                },
        { "app_url?"        , "网站URL"                 },
        { "bundle_id?"      , "iOS平台BundleID"         },
        { "package_name?"   , "Android平台PackageName"  },
    },
    SenceInfo = {
        { "payer_client_ip" , "用户终端IP"      },
        { "device_id?"      , "商户端设备号"    },
        { "store_info?"     , "商户门店信息"    , "@StoreInfo"  },
        { "h5_info?"        , "H5场景信息"      , "@H5Info"     },
    },
    PayerInfo = {
        { "sp_openid?"  , "用户服务标识"    },
        { "sub_openid?" , "用户子标识"      },
    },
    AmountInfo = {
        { "total"       , "订单总金额(单位元)"  , "number"  },
        { "currency?"   , "订单货币类型"                    },
    },
    OrderInfo = {
        { "sp_appid"        , "服务商应用ID"    },
        { "sp_mchid"        , "服务商户号"      },
        { "sub_appid?"      , "子商户应用ID"    },
        { "sub_mchid"       , "子商户号"        },
        { "description"     , "商品描述"        },
        { "out_trade_no"    , "商户订单号"      },
        { "time_expire?"    , "交易结束时间"    },
        { "attach?"         , "附加数据"        },
        { "notify_url"      , "通知地址"        },
        { "goods_tag?"      , "订单优惠标记"    },
        { "support_fapiao?" , "电子发票入口开放标识"    , "boolean" },

        -- 构造 amount
        { "amount_total"        , "订单总金额(单位元)"  , "number"  },
        { "amount_currency?"    , "订单货币类型"                    },
    },
}

__.jsapi__ = {
    "JSAPI下单",
--  https://pay.weixin.qq.com/wiki/doc/apiv3_partner/apis/chapter4_1_1.shtml
    req = "@JSAPIReq",
    types = {
        JSAPIReq = {
            "@OrderInfo",
            -- 构造 payer
                { "sp_openid?"  , "用户服务标识"    },
                { "sub_openid?" , "用户子标识"      },
        }
    },
    res = {
        { "appId"       , "应用ID"              },
        { "timeStamp"   , "时间戳"              },
        { "nonceStr"    , "随机字符串"          },
        { "package"     , "订单详情扩展字符串"  },
        { "signType"    , "签名方式"            },
        { "paySign"     , "签名"                },
    }
}
__.jsapi = function(t)

    local req = table.clone(t)  --> @JSAPIReq & { payer : @PayerInfo, amount : @AmountInfo }

    -- 构造 payer
    req.payer = {
        sp_openid  = req.sp_openid,
        sub_openid = req.sub_openid,
    }
    req.sp_openid  = nil
    req.sub_openid = nil

    -- 构造 amount
    req.amount = {
        total    = math.ceil( req.amount_total * 100 ),  -- 单位为分
        currency = req.amount_currency or "CNY",
    }
    req.amount_total      = nil
    req.amount_currency   = nil

    local res, err = wechatpay.utils.request {
        url  = "/v3/pay/partner/transactions/jsapi",
        body = cjson.encode(req)
    }
    if not res then return nil, err end

    -- 获取Jsapi微信支付包
    return wechatpay.utils.get_jsapi_package {
        appid       = req.sub_appid,
        prepay_id   = res.prepay_id,
    }

end

__.native__ = {
    "Native下单",
--  https://pay.weixin.qq.com/wiki/doc/apiv3_partner/apis/chapter4_4_1.shtml
    req = "@OrderInfo",
    res = {
        { "code_url"    , "二维码链接"  },
    }
}
__.native = function(t)

    local req = table.clone(t)  --> @OrderInfo & { amount : @AmountInfo }

    -- 构造 amount
    req.amount = {
        total    = math.ceil( req.amount_total * 100 ),  -- 单位为分
        currency = req.amount_currency,
    }

    req.amount_total      = nil
    req.amount_currency   = nil

    return wechatpay.utils.request {
        url  = "/v3/pay/partner/transactions/native",
        body = cjson.encode(req)
    }

end

__.h5__ = {
    "H5下单",
--  https://pay.weixin.qq.com/wiki/doc/apiv3_partner/apis/chapter4_3_1.shtml
    req = "@H5Req",
    types = {
        H5Req = {
            "@OrderInfo",
            { "scene_info?"  , "场景信息"    , "@SenceInfo"  }
        }
    },
    res = {
        { "h5_url"  , "支付跳转链接"    }, -- h5_url为拉起微信支付收银台的中间页面，有效期为5分钟。
    }
}
__.h5 = function(t)

    local req = table.clone(t)  --> @H5Req & { amount : @AmountInfo }

    -- 构造 amount
    req.amount = {
        total    = math.ceil( req.amount_total * 100 ),  -- 单位为分
        currency = req.amount_currency,
    }

    req.amount_total      = nil
    req.amount_currency   = nil

    -- 默认值
    if type(req.scene_info) ~= "table" then
        req.scene_info = {
            payer_client_ip = "127.0.0.1",
            h5_info = {
                type = "Wap"
            }
        }
    end

    return wechatpay.utils.request {
        url  = "/v3/pay/partner/transactions/h5",
        body = cjson.encode(req)
    }

end

__.query_by_id__ = {
    "按微信支付订单号查询",
--  https://pay.weixin.qq.com/wiki/doc/apiv3_partner/apis/chapter4_1_2.shtml
    req = {
        { "sp_mchid"        , "服务商户号"      },
        { "sub_mchid"       , "子商户号"        },
        { "transaction_id"  , "微信支付订单号"  },
    },
    types = {
        AmountInfoX = {
            "@AmountInfo",
            { "payer_total?"        , "用户支付金额"    , "number"  },
            { "payer_currency?"     , "用户支付币种"                },
        },
        OrderInfoX = {
            "@OrderInfo",
            { "transaction_id?"     , "微信支付订单号"              },
            { "trade_type?"         , "交易类型"                    },
            { "trade_state"         , "交易状态"                    },
            { "trade_state_desc?"   , "交易状态描述"                },
            { "bank_type?"          , "付款银行"                    },
            { "success_time?"       , "支付完成时间"                },
            { "payer"               , "支付者"      , "@PayerInfo"  },
            { "amount?"             , "订单金额"    , "@AmountInfoX"},
            { "scene_info?"         , "订单金额"    , "@SenceInfo"  },
            { "promotion_detail?"   , "优惠功能"    , "any"         },
        },
    },
    res = "@OrderInfoX"
}
__.query_by_id = function(t)

    local transaction_id = t.transaction_id

    local req = table.clone(t)
          req.transaction_id = nil

    local url = "/v3/pay/partner/transactions/id/"
              .. transaction_id .. "?"
              .. ngx.encode_args(req)

    return wechatpay.utils.request { url = url }

end

__.query__ = {
    "按商户订单号查询",
--  https://pay.weixin.qq.com/wiki/doc/apiv3_partner/apis/chapter4_1_2.shtml
    req = {
        { "sp_mchid"        , "服务商户号"      },
        { "sub_mchid"       , "子商户号"        },
        { "out_trade_no"    , "商户订单号"      },
    }
}
__.query = function(t)

    local out_trade_no = t.out_trade_no

    local req = table.clone(t)
          req.out_trade_no = nil

    local url = "/v3/pay/partner/transactions/out-trade-no/"
              .. out_trade_no .. "?"
              .. ngx.encode_args(req)

    return wechatpay.utils.request { url = url }

end

__.close__ = {
    "关闭订单API",
--  https://pay.weixin.qq.com/wiki/doc/apiv3_partner/apis/chapter4_1_3.shtml
    req = {
        { "sp_mchid"        , "服务商户号"      },
        { "sub_mchid"       , "子商户号"        },
        { "out_trade_no"    , "商户订单号"      },
    },
    res = "boolean"
}
__.close = function(t)

    local out_trade_no = t.out_trade_no

    local req = table.clone(t)
          req.out_trade_no = nil

    local  res, err = wechatpay.utils.request {
        url  = "/v3/pay/partner/transactions/out-trade-no/" .. out_trade_no .. "/close",
        body = cjson.encode(req),
    }
    if not res then return nil, err end

    return true

end

return __
