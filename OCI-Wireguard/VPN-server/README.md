
## Userdata 변경 처리

### VM 재생성 방지

`wireguard/main.tf`에서 `lifecycle.ignore_changes`를 사용하여 userdata 변경 시 VM이 재생성되지 않도록 설정되어 있습니다.

```hcl
lifecycle {
  ignore_changes = [
    metadata["user_data"],  # userdata 변경 무시
  ]
}
```

### Userdata 변경 시 적용 방법

Wireguard 설정(peers, 네트워크 등)이 변경되어도 VM이 재생성되지 않으므로, 수동으로 설정을 업데이트해야 합니다.

#### 1. Wireguard Peer 추가/변경

**terraform.tfvars 수정 후:**
```bash
terraform apply  # VM 재생성 없이 적용됨
```

**서버에 수동 적용:**
```bash
# SSH 접속
ssh ubuntu@<VPN_PUBLIC_IP>

# Wireguard 설정 수정
sudo nano /etc/wireguard/wg0.conf

# Peer 추가 예시:
# [Peer]
# PublicKey = NEW_CLIENT_PUBLIC_KEY
# AllowedIPs = 192.168.255.3/32

# Wireguard 재시작
sudo wg-quick down wg0
sudo wg-quick up wg0

# 또는 설정만 리로드
sudo wg syncconf wg0 <(wg-quick strip wg0)
```

#### 2. Remote Networks 변경

**terraform.tfvars 수정 후:**
```bash
terraform apply  # Route Table만 업데이트됨
```

서버의 Wireguard 설정은 자동으로 업데이트되지 않으므로, Route Table만 업데이트됩니다. Wireguard peer 설정은 위와 같이 수동으로 업데이트하세요.

#### 3. 완전히 새로운 설정 적용 (VM 재생성)

Userdata를 완전히 새로 적용하고 싶은 경우:

```bash
# VM 강제 재생성
terraform taint 'module.wireguard.oci_core_instance.main'
terraform apply

# 또는 VM 삭제 후 재생성
terraform destroy -target='module.wireguard.oci_core_instance.main'
terraform apply
```

**주의**: VM 재생성 시 Public IP가 변경될 수 있습니다 (Reserved IP를 사용하지 않는 경우).

### 장점

- ✅ Terraform 설정 변경 시 VM이 의도치 않게 재생성되는 것을 방지
- ✅ 운영 중인 서비스 중단 최소화
- ✅ Public IP 유지 (Reserved IP 미사용 시 중요)

### 단점

- ⚠️ 설정 변경 시 수동 적용 필요
- ⚠️ Terraform state와 실제 VM 상태가 다를 수 있음

### 권장 사항

1. **초기 배포**: userdata를 신중하게 설정
2. **Peer 추가**: SSH로 접속하여 수동 추가
3. **대규모 변경**: VM 재생성 고려
