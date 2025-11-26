#!/bin/bash
# Wireguard VPN 서버 디버깅 스크립트
# 사용법: SSH로 서버 접속 후 실행
#   ssh ubuntu@<VPN_IP> 'bash -s' < debug-server.sh

set -e

echo "=================================="
echo "Wireguard VPN 서버 진단 스크립트"
echo "=================================="
echo ""

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

# 1. Wireguard 서비스 상태
echo "=== 1. Wireguard 서비스 상태 ==="
if systemctl is-active --quiet wg-quick@wg0; then
    check_ok "Wireguard 서비스 실행 중"
else
    check_fail "Wireguard 서비스 중지됨"
    echo "해결: sudo wg-quick up wg0"
fi
echo ""

# 2. Wireguard 인터페이스 상태
echo "=== 2. Wireguard 인터페이스 ==="
if ip addr show wg0 &>/dev/null; then
    check_ok "wg0 인터페이스 존재"
    ip addr show wg0 | grep -E "inet |mtu"
else
    check_fail "wg0 인터페이스 없음"
fi
echo ""

# 3. Wireguard 설정
echo "=== 3. Wireguard 설정 ==="
if [ -f /etc/wireguard/wg0.conf ]; then
    check_ok "설정 파일 존재: /etc/wireguard/wg0.conf"
    echo "--- 설정 내용 (Private Key 제외) ---"
    sudo cat /etc/wireguard/wg0.conf | grep -v "^PrivateKey"
else
    check_fail "설정 파일 없음"
fi
echo ""

# 4. Wireguard 상태
echo "=== 4. Wireguard 피어 상태 ==="
WG_OUTPUT=$(sudo wg show wg0)
if [ -n "$WG_OUTPUT" ]; then
    check_ok "Wireguard 실행 중"
    echo "$WG_OUTPUT"

    # Peer 카운트
    PEER_COUNT=$(echo "$WG_OUTPUT" | grep -c "^peer:" || true)
    if [ "$PEER_COUNT" -gt 0 ]; then
        check_ok "등록된 Peer: $PEER_COUNT 개"
    else
        check_warn "등록된 Peer 없음 (terraform.tfvars의 wg_peers 확인)"
    fi
else
    check_fail "Wireguard 상태 정보 없음"
fi
echo ""

# 5. 리스닝 포트
echo "=== 5. Wireguard 리스닝 포트 ==="
if sudo netstat -ulnp 2>/dev/null | grep -q ":51820"; then
    check_ok "UDP 51820 포트 리스닝 중"
    sudo netstat -ulnp | grep ":51820"
else
    check_fail "UDP 51820 포트 리스닝 안함"
fi
echo ""

# 6. IP Forwarding
echo "=== 6. IP Forwarding ==="
IP_FORWARD=$(cat /proc/sys/net/ipv4/ip_forward)
if [ "$IP_FORWARD" = "1" ]; then
    check_ok "IP Forwarding 활성화됨"
else
    check_fail "IP Forwarding 비활성화됨"
    echo "해결: sudo sysctl -w net.ipv4.ip_forward=1"
fi
echo ""

# 7. iptables FORWARD 규칙
echo "=== 7. iptables FORWARD 규칙 ==="
FORWARD_RULES=$(sudo iptables -L FORWARD -n | grep -E "wg0|ens3" || true)
if [ -n "$FORWARD_RULES" ]; then
    check_ok "FORWARD 규칙 존재"
    echo "$FORWARD_RULES"
else
    check_warn "FORWARD 규칙 없음 (수동 추가 필요할 수 있음)"
    echo "추가 방법:"
    echo "  sudo iptables -A FORWARD -i ens3 -o wg0 -j ACCEPT"
    echo "  sudo iptables -A FORWARD -i wg0 -o ens3 -j ACCEPT"
fi
echo ""

# 8. 네트워크 인터페이스
echo "=== 8. 네트워크 인터페이스 ==="
echo "Public 인터페이스 (ens3):"
ip addr show ens3 | grep -E "inet " || check_warn "ens3 인터페이스 없음"
echo ""
echo "Wireguard 인터페이스 (wg0):"
ip addr show wg0 2>/dev/null | grep -E "inet " || check_warn "wg0 IP 주소 없음"
echo ""

# 9. 라우팅 테이블
echo "=== 9. 라우팅 테이블 ==="
ip route | grep -E "wg0|default"
echo ""

# 10. 최근 로그
echo "=== 10. Wireguard 최근 로그 (최근 20줄) ==="
sudo journalctl -u wg-quick@wg0 -n 20 --no-pager
echo ""

# 11. 시스템 리소스
echo "=== 11. 시스템 리소스 ==="
echo "메모리:"
free -h | grep -E "Mem:|Swap:"
echo ""
echo "디스크:"
df -h | grep -E "Filesystem|/dev/sda"
echo ""

# 12. 요약 및 권장사항
echo "=================================="
echo "진단 요약"
echo "=================================="

ISSUES=0

# Wireguard 서비스 체크
if ! systemctl is-active --quiet wg-quick@wg0; then
    check_fail "Wireguard 서비스 중지됨"
    ((ISSUES++))
fi

# IP Forwarding 체크
if [ "$IP_FORWARD" != "1" ]; then
    check_fail "IP Forwarding 비활성화됨"
    ((ISSUES++))
fi

# 포트 리스닝 체크
if ! sudo netstat -ulnp 2>/dev/null | grep -q ":51820"; then
    check_fail "Wireguard 포트 리스닝 안함"
    ((ISSUES++))
fi

# Peer 체크
if [ "$PEER_COUNT" -eq 0 ]; then
    check_warn "등록된 Peer 없음"
fi

if [ "$ISSUES" -eq 0 ]; then
    echo ""
    check_ok "모든 기본 체크 통과!"
    echo ""
    echo "다음 단계:"
    echo "1. 클라이언트에서 연결 시도"
    echo "2. 'sudo wg show' 로 handshake 확인"
    echo "3. 클라이언트에서 VPN 서버 Ping: ping $(ip addr show wg0 | grep -oP 'inet \K[\d.]+')"
else
    echo ""
    check_fail "$ISSUES 개의 문제 발견됨"
    echo ""
    echo "문제 해결 후 다시 실행하세요."
fi

echo ""
echo "=== Public Key (클라이언트 설정에 사용) ==="
sudo wg show wg0 public-key
echo ""
echo "=== Private IP (VPN 서버 주소) ==="
ip addr show wg0 2>/dev/null | grep -oP 'inet \K[\d.]+' || echo "wg0 인터페이스 없음"
echo ""
