#!/bin/bash
# Wireguard VPN 클라이언트 디버깅 스크립트
# 사용법: 클라이언트에서 실행
#   chmod +x debug-client.sh
#   ./debug-client.sh <VPN_SERVER_PUBLIC_IP>

set -e

# 색상 정의
RED='\033[0;31m'
GREEN='\033[0;32m'
YELLOW='\033[1;33m'
NC='\033[0m' # No Color

check_ok() {
    echo -e "${GREEN}[✓] $1${NC}"
}

check_fail() {
    echo -e "${RED}[✗] $1${NC}"
}

check_warn() {
    echo -e "${YELLOW}[!] $1${NC}"
}

# VPN 서버 IP 인자 확인
if [ -z "$1" ]; then
    echo "사용법: $0 <VPN_SERVER_PUBLIC_IP>"
    echo "예제: $0 132.145.123.45"
    exit 1
fi

VPN_SERVER_IP=$1
WG_CONFIG="/etc/wireguard/wg0.conf"

echo "=================================="
echo "Wireguard VPN 클라이언트 진단"
echo "=================================="
echo "VPN 서버: $VPN_SERVER_IP"
echo ""

# 1. Wireguard 설치 확인
echo "=== 1. Wireguard 설치 확인 ==="
if command -v wg &> /dev/null; then
    check_ok "Wireguard 설치됨"
    wg --version
else
    check_fail "Wireguard 미설치"
    echo "설치 방법:"
    echo "  Ubuntu/Debian: sudo apt install wireguard"
    echo "  macOS: brew install wireguard-tools"
    exit 1
fi
echo ""

# 2. 설정 파일 확인
echo "=== 2. 설정 파일 확인 ==="
if [ -f "$WG_CONFIG" ]; then
    check_ok "설정 파일 존재: $WG_CONFIG"
    echo "--- 설정 내용 (Private Key 제외) ---"
    sudo cat $WG_CONFIG | grep -v "^PrivateKey"

    # Endpoint 확인
    ENDPOINT=$(sudo cat $WG_CONFIG | grep -oP '^Endpoint = \K.+' || true)
    if [ -n "$ENDPOINT" ]; then
        if [[ "$ENDPOINT" == "$VPN_SERVER_IP"* ]]; then
            check_ok "Endpoint 설정 정확: $ENDPOINT"
        else
            check_warn "Endpoint 불일치: $ENDPOINT (예상: $VPN_SERVER_IP:51820)"
        fi
    else
        check_fail "Endpoint 설정 없음"
    fi
else
    check_fail "설정 파일 없음: $WG_CONFIG"
    echo ""
    echo "설정 파일 생성 방법:"
    echo "  sudo nano $WG_CONFIG"
    echo ""
    echo "예제 설정:"
    echo "[Interface]"
    echo "PrivateKey = <YOUR_CLIENT_PRIVATE_KEY>"
    echo "Address = 192.168.255.2/32"
    echo ""
    echo "[Peer]"
    echo "PublicKey = <SERVER_PUBLIC_KEY>"
    echo "Endpoint = $VPN_SERVER_IP:51820"
    echo "AllowedIPs = 192.168.0.0/16, 10.255.255.0/24"
    echo "PersistentKeepalive = 25"
    exit 1
fi
echo ""

# 3. VPN 서버 연결성 테스트
echo "=== 3. VPN 서버 연결성 테스트 ==="
echo "Ping 테스트..."
if ping -c 3 -W 3 $VPN_SERVER_IP &>/dev/null; then
    check_ok "VPN 서버 Ping 성공"
else
    check_fail "VPN 서버 Ping 실패"
    echo "  - 서버 IP가 정확한지 확인"
    echo "  - 서버의 Security List에서 ICMP 허용 확인"
fi
echo ""

# 4. UDP 51820 포트 테스트
echo "=== 4. UDP 51820 포트 테스트 ==="
echo "nc 또는 nmap으로 포트 테스트 (있는 경우)..."
if command -v nc &> /dev/null; then
    # nc로 UDP 포트 테스트는 제한적이므로 건너뜀
    check_warn "nc 설치됨 (수동으로 테스트: nc -vzu $VPN_SERVER_IP 51820)"
elif command -v nmap &> /dev/null; then
    if sudo nmap -sU -p 51820 $VPN_SERVER_IP 2>/dev/null | grep -q "open"; then
        check_ok "UDP 51820 포트 열림"
    else
        check_warn "UDP 51820 포트 상태 불확실 (nmap UDP 스캔은 부정확할 수 있음)"
    fi
else
    check_warn "nc나 nmap 미설치 (포트 테스트 건너뜀)"
fi
echo ""

# 5. Wireguard 인터페이스 상태
echo "=== 5. Wireguard 인터페이스 상태 ==="
if ip addr show wg0 &>/dev/null; then
    check_ok "wg0 인터페이스 존재 (VPN 연결 중)"
    ip addr show wg0 | grep -E "inet |mtu"

    # Wireguard 상태
    echo ""
    echo "Wireguard 상태:"
    WG_OUTPUT=$(sudo wg show wg0)
    echo "$WG_OUTPUT"

    # Handshake 확인
    if echo "$WG_OUTPUT" | grep -q "latest handshake"; then
        HANDSHAKE_TIME=$(echo "$WG_OUTPUT" | grep "latest handshake" | grep -oP '\d+ \w+ ago')
        check_ok "Handshake 성공: $HANDSHAKE_TIME"

        # Transfer 확인
        if echo "$WG_OUTPUT" | grep -q "transfer:.*received,.*sent"; then
            check_ok "데이터 전송 확인됨"
        fi
    else
        check_fail "Handshake 발생하지 않음"
        echo "  원인:"
        echo "  1. 서버의 Public Key 불일치"
        echo "  2. 클라이언트 Public Key가 서버에 등록되지 않음"
        echo "  3. UDP 51820 포트 차단"
        echo ""
        echo "  확인 방법:"
        echo "  - 서버 Public Key: ssh ubuntu@$VPN_SERVER_IP 'sudo wg show wg0 public-key'"
        echo "  - 클라이언트 Public Key: wg pubkey < <(sudo cat $WG_CONFIG | grep PrivateKey | cut -d' ' -f3)"
    fi
else
    check_warn "wg0 인터페이스 없음 (VPN 연결 안됨)"
    echo ""
    echo "VPN 연결 방법:"
    echo "  sudo wg-quick up wg0"
    echo ""
    echo "자동 시작 설정:"
    echo "  sudo systemctl enable wg-quick@wg0"
    echo "  sudo systemctl start wg-quick@wg0"
fi
echo ""

# 6. 라우팅 테이블
echo "=== 6. 라우팅 테이블 ==="
if ip addr show wg0 &>/dev/null; then
    echo "Wireguard 관련 라우트:"
    ip route | grep wg0 || check_warn "wg0 관련 라우트 없음"

    # VPN 서버 IP 대역 라우팅 확인
    VPN_SERVER_CIDR=$(sudo cat $WG_CONFIG | grep "AllowedIPs" | grep -oP '\d+\.\d+\.\d+\.\d+/\d+' | head -1)
    if [ -n "$VPN_SERVER_CIDR" ]; then
        if ip route | grep -q "$VPN_SERVER_CIDR.*wg0"; then
            check_ok "VPN 서버 대역 라우팅 설정됨: $VPN_SERVER_CIDR"
        else
            check_warn "VPN 서버 대역 라우팅 없음 (AllowedIPs 확인)"
        fi
    fi
else
    check_warn "wg0 인터페이스 없음 (라우팅 확인 불가)"
fi
echo ""

# 7. VPN 터널 Ping 테스트
echo "=== 7. VPN 터널 Ping 테스트 ==="
if ip addr show wg0 &>/dev/null; then
    # VPN 서버 Private IP 추출 (AllowedIPs에서 첫 번째 IP)
    VPN_PRIVATE_IP=$(sudo cat $WG_CONFIG | grep "AllowedIPs" | grep -oP '10\.\d+\.\d+\.\d+' | head -1)

    if [ -z "$VPN_PRIVATE_IP" ]; then
        # 기본값으로 시도
        VPN_PRIVATE_IP="10.255.255.10"
    fi

    echo "VPN 서버 Private IP Ping: $VPN_PRIVATE_IP"
    if ping -c 3 -W 3 $VPN_PRIVATE_IP &>/dev/null; then
        check_ok "VPN 터널 Ping 성공"
    else
        check_fail "VPN 터널 Ping 실패"
        echo "  원인:"
        echo "  1. Handshake가 발생하지 않음"
        echo "  2. 서버의 IP Forwarding 비활성화"
        echo "  3. 서버의 iptables FORWARD 규칙 누락"
        echo "  4. AllowedIPs에 VPN 서버 IP 대역 미포함"
    fi
else
    check_warn "wg0 인터페이스 없음 (VPN 연결 먼저 시도)"
fi
echo ""

# 8. DNS 확인
echo "=== 8. DNS 설정 ==="
if grep -q "nameserver" /etc/resolv.conf; then
    echo "현재 DNS 서버:"
    grep "nameserver" /etc/resolv.conf
else
    check_warn "DNS 설정 없음"
fi
echo ""

# 9. 방화벽 확인 (Linux)
if command -v ufw &> /dev/null; then
    echo "=== 9. UFW 방화벽 ==="
    UFW_STATUS=$(sudo ufw status 2>/dev/null || echo "inactive")
    if [[ "$UFW_STATUS" == *"Status: active"* ]]; then
        check_warn "UFW 활성화됨 (Wireguard 트래픽 차단 가능성)"
        echo "  UFW 규칙:"
        sudo ufw status | grep -E "51820|ALLOW"
    else
        check_ok "UFW 비활성화됨"
    fi
    echo ""
fi

# 10. 요약
echo "=================================="
echo "진단 요약"
echo "=================================="

ISSUES=0

# VPN 연결 여부
if ! ip addr show wg0 &>/dev/null; then
    check_fail "VPN 연결 안됨 (wg0 인터페이스 없음)"
    echo "  해결: sudo wg-quick up wg0"
    ((ISSUES++))
else
    # Handshake 확인
    WG_OUTPUT=$(sudo wg show wg0)
    if ! echo "$WG_OUTPUT" | grep -q "latest handshake"; then
        check_fail "Handshake 발생하지 않음"
        echo "  1. 서버 Public Key 확인"
        echo "  2. 서버에 클라이언트 Peer 등록 확인"
        echo "  3. UDP 51820 포트 확인"
        ((ISSUES++))
    else
        check_ok "Handshake 성공"

        # Ping 테스트
        VPN_PRIVATE_IP=$(sudo cat $WG_CONFIG | grep "AllowedIPs" | grep -oP '10\.\d+\.\d+\.\d+' | head -1)
        if [ -z "$VPN_PRIVATE_IP" ]; then
            VPN_PRIVATE_IP="10.255.255.10"
        fi

        if ! ping -c 1 -W 2 $VPN_PRIVATE_IP &>/dev/null; then
            check_warn "VPN 터널 Ping 실패"
            echo "  서버 측 IP Forwarding 및 iptables 확인 필요"
        else
            check_ok "VPN 터널 정상 작동"
        fi
    fi
fi

if [ "$ISSUES" -eq 0 ]; then
    echo ""
    check_ok "기본 체크 완료!"
else
    echo ""
    check_fail "$ISSUES 개의 문제 발견"
fi

echo ""
echo "=== 추가 정보 ==="
echo "클라이언트 Public Key (서버 등록용):"
if [ -f "$WG_CONFIG" ]; then
    sudo cat $WG_CONFIG | grep PrivateKey | cut -d' ' -f3 | wg pubkey
else
    echo "설정 파일 없음"
fi
echo ""
echo "상세 디버깅:"
echo "  서버 로그 확인: ssh ubuntu@$VPN_SERVER_IP 'sudo journalctl -u wg-quick@wg0 -f'"
echo "  클라이언트 로그: sudo journalctl -u wg-quick@wg0 -f"
echo ""
