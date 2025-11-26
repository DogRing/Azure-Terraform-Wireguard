# Wireguard VPN 디버깅 스크립트

연결 문제를 빠르게 진단하는 자동화 스크립트입니다.

---

## 📋 스크립트 목록

### 1. `debug-server.sh` - 서버 진단 스크립트

VPN 서버의 상태를 자동으로 확인합니다.

**사용 방법:**

#### Option A: SSH로 직접 실행
```bash
ssh ubuntu@<VPN_PUBLIC_IP> 'bash -s' < debug-server.sh
```

#### Option B: 서버에 복사 후 실행
```bash
scp debug-server.sh ubuntu@<VPN_PUBLIC_IP>:~/
ssh ubuntu@<VPN_PUBLIC_IP>
chmod +x debug-server.sh
./debug-server.sh
```

#### Option C: 원라인 명령
```bash
ssh ubuntu@<VPN_PUBLIC_IP> 'curl -sL https://raw.githubusercontent.com/your-repo/OCI-Wireguard/main/scripts/debug-server.sh | bash'
```

**확인 항목:**
- ✅ Wireguard 서비스 상태
- ✅ wg0 인터페이스 존재 여부
- ✅ Wireguard 설정 파일
- ✅ 등록된 Peer 개수
- ✅ UDP 51820 리스닝 상태
- ✅ IP Forwarding 활성화
- ✅ iptables FORWARD 규칙
- ✅ 네트워크 인터페이스
- ✅ 라우팅 테이블
- ✅ 최근 로그

**출력 예시:**
```
==================================
Wireguard VPN 서버 진단 스크립트
==================================

=== 1. Wireguard 서비스 상태 ===
[✓] Wireguard 서비스 실행 중

=== 2. Wireguard 인터페이스 ===
[✓] wg0 인터페이스 존재
    inet 10.255.255.10/24 scope global wg0

=== 3. Wireguard 설정 ===
[✓] 설정 파일 존재: /etc/wireguard/wg0.conf
--- 설정 내용 (Private Key 제외) ---
[Interface]
Address = 10.255.255.10
ListenPort = 51820

[Peer]
PublicKey = CLIENT_PUBLIC_KEY_HERE
AllowedIPs = 192.168.255.2/32

=== 4. Wireguard 피어 상태 ===
[✓] Wireguard 실행 중
interface: wg0
  public key: SERVER_PUBLIC_KEY
  private key: (hidden)
  listening port: 51820

peer: CLIENT_PUBLIC_KEY
  allowed ips: 192.168.255.2/32
  latest handshake: 15 seconds ago
  transfer: 1.23 KiB received, 892 B sent

[✓] 등록된 Peer: 1 개

=== 5. Wireguard 리스닝 포트 ===
[✓] UDP 51820 포트 리스닝 중

=== 6. IP Forwarding ===
[✓] IP Forwarding 활성화됨

=== 7. iptables FORWARD 규칙 ===
[✓] FORWARD 규칙 존재

==================================
진단 요약
==================================

[✓] 모든 기본 체크 통과!

다음 단계:
1. 클라이언트에서 연결 시도
2. 'sudo wg show' 로 handshake 확인
3. 클라이언트에서 VPN 서버 Ping: ping 10.255.255.10

=== Public Key (클라이언트 설정에 사용) ===
SERVER_PUBLIC_KEY_HERE

=== Private IP (VPN 서버 주소) ===
10.255.255.10
```

---

### 2. `debug-client.sh` - 클라이언트 진단 스크립트

VPN 클라이언트의 연결 상태를 확인합니다.

**사용 방법:**
```bash
chmod +x debug-client.sh
./debug-client.sh <VPN_SERVER_PUBLIC_IP>
```

**예제:**
```bash
./debug-client.sh 132.145.123.45
```

**확인 항목:**
- ✅ Wireguard 설치 여부
- ✅ 설정 파일 존재 및 내용
- ✅ Endpoint 설정 정확성
- ✅ VPN 서버 Ping 테스트
- ✅ UDP 51820 포트 테스트
- ✅ wg0 인터페이스 상태
- ✅ Handshake 발생 여부
- ✅ 라우팅 테이블
- ✅ VPN 터널 Ping 테스트
- ✅ DNS 설정
- ✅ 방화벽 상태

**출력 예시:**
```
==================================
Wireguard VPN 클라이언트 진단
==================================
VPN 서버: 132.145.123.45

=== 1. Wireguard 설치 확인 ===
[✓] Wireguard 설치됨
wireguard-tools v1.0.20210914

=== 2. 설정 파일 확인 ===
[✓] 설정 파일 존재: /etc/wireguard/wg0.conf
--- 설정 내용 (Private Key 제외) ---
[Interface]
Address = 192.168.255.2/32

[Peer]
PublicKey = SERVER_PUBLIC_KEY
Endpoint = 132.145.123.45:51820
AllowedIPs = 192.168.0.0/16, 10.255.255.0/24
PersistentKeepalive = 25

[✓] Endpoint 설정 정확: 132.145.123.45:51820

=== 3. VPN 서버 연결성 테스트 ===
Ping 테스트...
[✓] VPN 서버 Ping 성공

=== 5. Wireguard 인터페이스 상태 ===
[✓] wg0 인터페이스 존재 (VPN 연결 중)
    inet 192.168.255.2/32 scope global wg0

Wireguard 상태:
interface: wg0
  public key: CLIENT_PUBLIC_KEY
  private key: (hidden)

peer: SERVER_PUBLIC_KEY
  endpoint: 132.145.123.45:51820
  allowed ips: 192.168.0.0/16, 10.255.255.0/24
  latest handshake: 8 seconds ago
  transfer: 2.45 KiB received, 1.23 KiB sent
  persistent keepalive: every 25 seconds

[✓] Handshake 성공: 8 seconds ago
[✓] 데이터 전송 확인됨

=== 7. VPN 터널 Ping 테스트 ===
VPN 서버 Private IP Ping: 10.255.255.10
[✓] VPN 터널 Ping 성공

==================================
진단 요약
==================================

[✓] 기본 체크 완료!

[✓] VPN 터널 정상 작동

=== 추가 정보 ===
클라이언트 Public Key (서버 등록용):
CLIENT_PUBLIC_KEY_HERE
```

---

## 🚀 빠른 진단 플로우

### 1단계: 서버 진단
```bash
# 서버 상태 확인
ssh ubuntu@<VPN_PUBLIC_IP> 'bash -s' < debug-server.sh

# 문제가 있으면 로그 확인
ssh ubuntu@<VPN_PUBLIC_IP> 'sudo journalctl -u wg-quick@wg0 -f'
```

### 2단계: 클라이언트 진단
```bash
# 클라이언트 상태 확인
./debug-client.sh <VPN_PUBLIC_IP>

# VPN 연결 시도
sudo wg-quick up wg0

# 연결 확인
sudo wg show
```

### 3단계: 상호 확인
```bash
# 서버에서 클라이언트 Peer 확인
ssh ubuntu@<VPN_PUBLIC_IP> 'sudo wg show wg0 peers'

# 클라이언트에서 Handshake 확인
sudo wg show wg0 | grep handshake
```

---

## 🔍 문제별 빠른 해결

### 문제 1: Handshake 안됨

**서버 확인:**
```bash
ssh ubuntu@<VPN_PUBLIC_IP> 'bash -s' < debug-server.sh | grep -A5 "Peer"
```

**클라이언트 Public Key 확인:**
```bash
./debug-client.sh <VPN_PUBLIC_IP> | grep "클라이언트 Public Key"
```

**서버에 Peer 추가:**
```bash
cd OCI-Wireguard/VPN-server
# terraform.tfvars 수정
terraform apply
```

---

### 문제 2: Ping 안됨

**IP Forwarding 확인:**
```bash
ssh ubuntu@<VPN_PUBLIC_IP> 'cat /proc/sys/net/ipv4/ip_forward'
# 출력: 1 이어야 함
```

**iptables 확인:**
```bash
ssh ubuntu@<VPN_PUBLIC_IP> 'sudo iptables -L FORWARD -v -n | grep wg0'
```

**수동 수정:**
```bash
ssh ubuntu@<VPN_PUBLIC_IP>
sudo sysctl -w net.ipv4.ip_forward=1
sudo iptables -A FORWARD -i ens3 -o wg0 -j ACCEPT
sudo iptables -A FORWARD -i wg0 -o ens3 -j ACCEPT
sudo netfilter-persistent save
```

---

### 문제 3: Security Rules

**NSG 확인:**
```bash
cd OCI-Wireguard/VPN-server
terraform state show 'module.network.oci_core_network_security_group_security_rule.wireguard_inbound'
```

**Security List 확인 (OCI Console):**
```
Networking → VCN → Security Lists
→ Ingress Rules
→ UDP 51820 확인
```

---

## 📊 로그 수집 명령어

### 서버 로그
```bash
# 실시간 로그
ssh ubuntu@<VPN_PUBLIC_IP> 'sudo journalctl -u wg-quick@wg0 -f'

# 최근 100줄
ssh ubuntu@<VPN_PUBLIC_IP> 'sudo journalctl -u wg-quick@wg0 -n 100'

# 패킷 캡처 (tcpdump)
ssh ubuntu@<VPN_PUBLIC_IP> 'sudo tcpdump -i ens3 -n udp port 51820 -v'
```

### 클라이언트 로그
```bash
# 실시간 로그 (systemd 사용 시)
sudo journalctl -u wg-quick@wg0 -f

# 수동 연결 시 로그
sudo wg-quick up wg0

# 상태 확인
sudo wg show wg0
```

---

## 🛠️ 완전 재설정

### 서버 재설정
```bash
# VPN 서버 SSH 접속
ssh ubuntu@<VPN_PUBLIC_IP>

# Wireguard 중지
sudo wg-quick down wg0

# 설정 백업
sudo cp /etc/wireguard/wg0.conf /etc/wireguard/wg0.conf.bak

# Terraform으로 재배포
exit
cd OCI-Wireguard/VPN-server
terraform taint 'module.wireguard.oci_core_instance.main'
terraform apply
```

### 클라이언트 재설정
```bash
# VPN 연결 중지
sudo wg-quick down wg0

# 설정 백업
sudo cp /etc/wireguard/wg0.conf /etc/wireguard/wg0.conf.bak

# 새 키 생성
wg genkey | tee client_private.key | wg pubkey > client_public.key

# 설정 파일 수정
sudo nano /etc/wireguard/wg0.conf

# 재연결
sudo wg-quick up wg0
```

---

## 📞 추가 지원

상세한 문제 해결 가이드:
- `TROUBLESHOOTING.md`: 단계별 디버깅 가이드
- `DEPLOYMENT_GUIDE.md`: 배포 및 설정 가이드
- `COMPARISON_SUMMARY.md`: Azure vs OCI 비교

GitHub Issues: 문제를 발견하면 이슈 등록

---

## 💡 팁

### 자주 사용하는 명령어 Alias
```bash
# ~/.bashrc 또는 ~/.zshrc에 추가
alias wg-status='sudo wg show'
alias wg-start='sudo wg-quick up wg0'
alias wg-stop='sudo wg-quick down wg0'
alias wg-restart='sudo wg-quick down wg0 && sudo wg-quick up wg0'
alias wg-logs='sudo journalctl -u wg-quick@wg0 -f'
```

### 빠른 상태 확인 원라이너
```bash
# 서버
ssh ubuntu@<VPN_IP> "echo 'WG:' && sudo wg show && echo -e '\nIP Forward:' && cat /proc/sys/net/ipv4/ip_forward && echo -e '\nPort:' && sudo netstat -ulnp | grep 51820"

# 클라이언트
echo "WG:" && sudo wg show && echo -e "\nPing:" && ping -c 3 10.255.255.10
```
