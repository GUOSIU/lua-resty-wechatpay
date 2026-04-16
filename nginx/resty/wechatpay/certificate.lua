
local wechatpay = require "resty.wechatpay"

local __ = { ver = "v24.05.17" }

__.list__ = {
    "获取平台证书列表",
--  https://wechatpay-api.gitbook.io/wechatpay-api-v3/jie-kou-wen-dang/ping-tai-zheng-shu
    types = {
        CertificateData = {
            serial_no       = "string //序列号",
            effective_time  = "string //生效时间",
            expire_time     = "string //过期时间",
            encrypt_certificate = {
                algorithm       = "string //加密算法: AEAD_AES_256_GCM",
                nonce           = "string //加密使用的随机串初始化向量",
                associated_data = "string //附加数据包: certificate",
                ciphertext      = "string //Base64编码后的密文",
            },
            certificate     = "string //解密后证书",
            public_key      = "string //导出的公钥",
        }
    },
    res = "@CertificateData[]"
}
__.list = function()

    -- 微信支付V3版本的openresty实现与避坑指南（服务端）
    -- https://blog.csdn.net/sirria1/article/details/114066808

    local  res, err = wechatpay.utils.request { url = "/v3/certificates" }
    if not res then return nil, err end

    local certs = res.data  --> @return

    for _, d in ipairs(certs) do
        local  cert, err = wechatpay.utils.aes_256_gcm_decrypt(d.encrypt_certificate)
        if not cert then return nil, err end

        local  pkey, err = wechatpay.utils.get_public_key(cert)
        if not pkey then return nil, err end

        d.certificate = cert
        d.public_key  = pkey
    end

    return certs

end

return __
