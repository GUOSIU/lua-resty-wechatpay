
local tonumber  = tonumber
local wechatpay = require "resty.wechatpay"

local __ = { ver = "v24.10.17" }

__.types = {
    BankInfo = {
        { "bank_alias"          , "银行别名"        },
        { "bank_alias_code"     , "银行别名编码"    },
        { "account_bank"        , "开户银行"        },
        { "account_bank_code"   , "开户银行编码"        , "int"     },
        { "need_bank_branch"    , "是否需要填写支行"    , "boolean" },
    },
    BranchInfo = {
        { "bank_branch_name"    , "开户银行支行名称"        },
        { "bank_branch_id"      , "开户银行支行联行号"      },
    },
    LinkInfo = {
        { "next"    , "下一页链接"  },
        { "prev"    , "上一页链接"  },
        { "self"    , "当前链接"    },
    }
}

__.search_banks_by_bank_account__ = {
    "获取对私银行卡号开户银行",  -- （仅支持部分银行的对私银行卡）
--   https://pay.weixin.qq.com/wiki/doc/apiv3_partner/Offline/apis/chapter11_2_1.shtml
    req = {
        { "account_number"  , "银行卡号(加密)"  },
    },
    res = {
        { "data"        , "银行列表"            , "@BankInfo[]" },
        { "total_count" , "查询数据总条数"      , "number"      },
    }
}
__.search_banks_by_bank_account = function(t)

    t.account_number = wechatpay.utils.encrypt(t.account_number)  -- 敏感信息加密
    return wechatpay.utils.request {
        url  = "/v3/capital/capitallhh/banks/search-banks-by-bank-account",
        args = { account_number = t.account_number },
    }
end

__.personal_banking__ = {
    "查询支持个人业务的银行列表",
--  https://pay.weixin.qq.com/wiki/doc/apiv3_partner/Offline/apis/chapter11_2_2.shtml
    req = {
        { "offset?" , "本次查询偏移量"      , "number"  },
        { "limit?"  , "本次请求最大查询条数", "number"  },
    },
    res = {
        { "data"        , "银行列表"            , "@BankInfo[]" },
        { "links"       , "分页链接"            , "@LinkInfo"   },
        { "total_count" , "查询数据总条数"      , "number"      },
        { "count"       , "本次查询数据条数"    , "number"      },
        { "offset"      , "本次查询偏移量"      , "number"      },
    }
}
__.personal_banking = function(t)

    t.offset = tonumber(t.offset ) or 0
    t.limit  = tonumber(t.limit  ) or 200

    return wechatpay.utils.request {
        url  = "/v3/capital/capitallhh/banks/personal-banking",
        args = { offset = t.offset, limit = t.limit },
    }

end

__.corporate_banking__ = {
    "查询支持对公业务的银行列表",
--  https://pay.weixin.qq.com/wiki/doc/apiv3_partner/Offline/apis/chapter11_2_3.shtml
    req = {
        { "offset?" , "本次查询偏移量"      , "number"  },
        { "limit?"  , "本次请求最大查询条数", "number"  },
    },
    res = {
        { "data"        , "银行列表"            , "@BankInfo[]" },
        { "links"       , "分页链接"            , "@LinkInfo"   },
        { "total_count" , "查询数据总条数"      , "number"  },
        { "count"       , "本次查询数据条数"    , "number"  },
        { "offset"      , "本次查询偏移量"      , "number"  },
    }
}
__.corporate_banking = function(t)

    t.offset = tonumber(t.offset ) or 0
    t.limit  = tonumber(t.limit  ) or 200

    return wechatpay.utils.request {
        url  = "/v3/capital/capitallhh/banks/corporate-banking",
        args = { offset = t.offset, limit = t.limit },
    }

end

__.banks_branches__ = {
    "查询支行列表API",
--  https://pay.weixin.qq.com/wiki/doc/apiv3_partner/Offline/apis/chapter11_2_6.shtml
    req = {
        { "bank_alias_code"     , "银行别名编码"                    },
        { "city_code"           , "城市编码"            , "number"  },
        { "offset?"             , "本次查询偏移量"      , "number"  },
        { "limit?"              , "本次请求最大查询条数", "number"  },
    },
    res = {
        { "data"                , "银行列表"            , "@BranchInfo[]"   },
        { "links"               , "分页链接"            , "@LinkInfo"       },
        { "total_count"         , "查询数据总条数"      , "number"          },
        { "count"               , "本次查询数据条数"    , "number"          },
        { "offset"              , "本次查询偏移量"      , "number"          },
        { "account_bank"        , "开户银行"                                },
        { "account_bank_code"   , "开户银行编码"                            },
        { "bank_alias"          , "银行别名"                                },
        { "bank_alias_code"     , "银行别名编码"                            },
    }
}
__.banks_branches = function(t)

    t.offset = tonumber(t.offset ) or 0
    t.limit  = tonumber(t.limit  ) or 100

    return wechatpay.utils.request {
        url  = "/v3/capital/capitallhh/banks/" .. t.bank_alias_code .. "/branches",
        args = { city_code = t.city_code, offset = t.offset, limit = t.limit },
    }

end

__.provinces__ = {
    "查询省份列表API",
--  https://pay.weixin.qq.com/wiki/doc/apiv3_partner/Offline/apis/chapter11_2_4.shtml
    types = {
        ProvinceInfo = {
            { "province_name"   , "省份名称" },
            { "province_code"   , "省份编码" },
        }
    },
    res = {
        { "data"        , "省份列表"                    },
        { "total_count" , "查询数据总条数"  , "number"  },
    }
}
__.provinces = function()
    return wechatpay.utils.request {
        url = "/v3/capital/capitallhh/areas/provinces",
    }
end

__.cities__ = {
    "查询城市列表API",
--  https://pay.weixin.qq.com/wiki/doc/apiv3_partner/Offline/apis/chapter11_2_5.shtml
    req = {
        { "province_code" , "省份编码" },
    },
    types = {
        CityInfo = {
            { "city_name"   , "城市名称" },
            { "city_code"   , "城市编码" },
        }
    },
    res = {
        { "data"        , "城市列表"                    },
        { "total_count" , "查询数据总条数"  , "number"  },
    }
}
__.cities = function(t)
    return wechatpay.utils.request {
        url = "/v3/capital/capitallhh/areas/provinces/" .. t.province_code .. "/cities",
    }
end

return __
