
local wechatpay     = require "resty.wechatpay"
local cjson         = require "cjson.safe"

local __ = { ver = "v24.10.17" }

__.get_settlement__ = {
    "查询结算账户",
--  https://pay.weixin.qq.com/docs/partner/apis/modify-settlement/sub-merchants/get-settlement.html
    req = {
        { "sub_mchid"   , "特约商户/二级商户号" },
    },
    res = {
        { "account_type"    , "账户类型"    }, -- ACCOUNT_TYPE_BUSINESS 对公银行账户 ; ACCOUNT_TYPE_PRIVATE 经营者个人银行卡
        { "account_bank"    , "开户银行"    },
        { "bank_name"       , "开户银行全称（含支行）"  },
        { "bank_branch_id"  , "开户银行联行号"          },
        { "account_number"  , "银行账号"    },
        { "verify_result"   , "验证结果"    }, -- VERIFY_SUCCESS 验证成功 VERIFY_FAIL 验证失败 VERIFYING 验证中
        { "verify_fail_reason", "验证失败原因" },
    }
}
__.get_settlement = function(t)
    return wechatpay.utils.request {
        url  = "/v3/apply4sub/sub_merchants/" .. t.sub_mchid .. "/settlement",
    }
end

local ACCOUNTTYPE = {
    ["ACCOUNT_TYPE_BUSINESS"] = true,  -- 对公银行账户
    ["ACCOUNT_TYPE_PRIVATE"]  = true,  -- 经营者个人银行卡
}

__.modify_settlement__ = {
    "修改结算账户",
--  https://pay.weixin.qq.com/docs/partner/apis/modify-settlement/sub-merchants/modify-settlement.html
    req = {
        { "sub_mchid"       , "特约商户/二级商户号"     },
        { "account_type"    , "账户类型"                },
        { "account_bank"    , "开户银行"                },
        { "bank_name?"      , "开户银行全称（含支行）"  },
        { "bank_branch_id?" , "开户银行联行号"          },
        { "account_number"  , "银行账号(加密)"          },
        { "account_name?"   , "开户名称(加密)"          },
    },
    res = {
        { "application_no"  , "修改结算账户申请单号"    },
    }
}
__.modify_settlement = function(t)

    if not ACCOUNTTYPE[t.account_type] then
        return nil, "账户类型不匹配"
    end

    if  t.account_number then
        t.account_number = wechatpay.utils.encrypt(t.account_number)  -- 敏感信息加密
    end

    if  t.account_name then
        t.account_name = wechatpay.utils.encrypt(t.account_name)  -- 敏感信息加密
    end

    return wechatpay.utils.request {
        url  = "/v3/apply4sub/sub_merchants/" .. t.sub_mchid .. "/modify-settlement",
        body = cjson.encode {
            account_type    = t.account_type,
            account_bank    = t.account_bank,
            bank_branch_id  = t.bank_branch_id,
            bank_name       = t.bank_name,
            account_number  = t.account_number,
            account_name    = t.account_name,
        }
    }

end

__.query_application__ = {
    "查询结算账户修改申请状态",
--  https://pay.weixin.qq.com/docs/partner/apis/modify-settlement/sub-merchants/get-application.html
    req = {
        { "sub_mchid"       , "特约商户/二级商户号"     },
        { "application_no"  , "修改结算账户申请单号"    },
    },
    res = {
        { "account_number"  , "银行账号"    },
        { "account_type"    , "账户类型"    }, -- ACCOUNT_TYPE_BUSINESS 对公银行账户 ; ACCOUNT_TYPE_PRIVATE 经营者个人银行卡
        { "account_bank"    , "开户银行"    },
        { "bank_name"       , "开户银行全称（含支行）"  },
        { "bank_branch_id"  , "开户银行联行号"          },
        { "verify_result"   , "验证结果"    }, -- VERIFY_SUCCESS 验证成功 VERIFY_FAIL 验证失败 VERIFYING 验证中
        { "verify_fail_reason", "验证失败原因"      },
        { "verify_finish_time", "审核结果更新时间"  },
    }
}
__.query_application = function(t)
    return wechatpay.utils.request {
        url = "/v3/apply4sub/sub_merchants/" .. t.sub_mchid .. "/application/" .. t.application_no,
    }
end

return __
