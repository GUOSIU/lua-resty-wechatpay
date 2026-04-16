
local wechatpay         = require "resty.wechatpay"
local cjson             = require "cjson.safe"

local __ = { ver = "v24.05.21" }

__.types = {
    AmountInfo = {
        { "refund"      , "退款金额(单位分)"    , "number"  },
        { "total"       , "原订单金额(单位分)"  , "number"  },
        { "currency"    , "退款币种"                        },
    },
    AmountInfoX = {
        "@AmountInfo",
        { "payer_total"         , "用户支付金额(单位分)"  , "number"  },
        { "payer_refund"        , "用户退款金额(单位分)"  , "number"  },
        { "settlement_refund"   , "应结退款金额(单位分)"  , "number"  },
        { "settlement_total"    , "应结订单金额(单位分)"  , "number"  },
        { "discount_refund"     , "优惠退款金额(单位分)"  , "number"  },
        { "refund_fee"          , "手续费退款金额(单位分)", "number"  },
    },
    GoodsInfo = {
        { "merchant_goods_id"   , "商户侧商品编码"      },
        { "wechatpay_goods_id?" , "微信支付商品编码"    },
        { "goods_name?"         , "商品名称"            },
        { "unit_price"          , "商品单价(单位分)"    , "number"  },
        { "refund_amount"       , "商品退款金额(单位分)", "number"  },
        { "refund_quantity"     , "商品退货数量"        , "number"  },
    },
    PromotionInfo = {
        { "promotion_id"    , "券ID"        },
        { "scope"           , "优惠范围"    },
        { "type"            , "优惠类型"    },
        { "amount"          , "优惠券面额(单位分)"      , "number"  },
        { "refund_amount"   , "优惠退款金额(单位分)"    , "number"  },
        { "goods_detail?"   , "优惠类型"    , "@GoodsInfo[]"        },
    },
    RefundOrder = {
        { "refund_id"               , "微信支付退款单号"},
        { "out_refund_no"           , "商户退款单号"    },
        { "transaction_id"          , "微信支付订单号"  },
        { "out_trade_no"            , "商户订单号"      },
        { "channel"                 , "退款渠道"        },
        { "user_received_account"   , "退款入账账户"    },
        { "success_time?"           , "退款成功时间"    },
        { "create_time"             , "退款创建时间"    },
        { "status"                  , "退款状态"        },
        { "funds_account?"          , "资金账户"        },
        { "amount"                  , "金额信息"    , "@AmountInfoX"    },
        { "promotion_detail?"       , "优惠退款信息", "@PromotionInfo[]"},
    }
}

__.create__ = {
    "申请退款(refunds接口)",
--  https://pay.weixin.qq.com/wiki/doc/apiv3_partner/apis/chapter4_1_9.shtml
    req = {
        { "sub_mchid"       , "子商户号"        },
        { "transaction_id?" , "微信支付订单号"  },
        { "out_trade_no"    , "商户订单号"      },
        { "out_refund_no"   , "商户退款单号"    },
        { "reason?"         , "退款原因"        },
        { "notify_url?"     , "退款结果回调url" },
        { "funds_account?"  , "退款资金来源"    },

        { "amount_refund"       , "退款金额(单位元)"    , "number"  },
        { "amount_total"        , "原订单金额(单位元)"  , "number"  },
        { "amount_currency?"    , "退款币种"                        },
    },
    res = "@RefundOrder"
}
__.create = function(t)

    local req = table.clone(t)  --> req<__.create> & { amount : @AmountInfo }

    -- 构造 amount
    req.amount = {
        refund   = math.ceil( req.amount_refund * 100 ),  -- 单位为分
        total    = math.ceil( req.amount_total  * 100 ),  -- 单位为分
        currency = req.amount_currency or "CNY",
    }
    req.amount_refund   = nil
    req.amount_total    = nil
    req.amount_currency = nil

    return wechatpay.utils.request {
        url  = "/v3/refund/domestic/refunds",
        body = cjson.encode(req)
    }

end

__.query__ = {
    "查询单笔退款",
--  https://pay.weixin.qq.com/wiki/doc/apiv3_partner/apis/chapter4_1_10.shtml
    req = {
        { "out_refund_no"   , "商户订单号"  },
        { "sub_mchid"       , "子商户号"    },
    },
    res = "@RefundOrder"
}
__.query = function(t)

    local out_refund_no = t.out_refund_no

    local req = table.clone(t)
          req.out_refund_no = nil

    local url = "/v3/refund/domestic/refunds/" .. out_refund_no .. "?"
              .. ngx.encode_args(req)

    return wechatpay.utils.request { url = url }

end

return __
