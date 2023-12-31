#!/bin/bash

red='\033[0;31m'
green='\033[0;32m'
yellow='\033[0;33m'
plain='\033[0m'

version="v1.0.0"

# check root
[[ $EUID -ne 0 ]] && echo -e "${red}Nhầm Lẫn: ${plain} Chưa Vào Root , Vào Root Trước Khi Sử Dụng！\n" && exit 1

# check os
if [[ -f /etc/redhat-release ]]; then
    release="centos"
elif cat /etc/issue | grep -Eqi "debian"; then
    release="debian"
elif cat /etc/issue | grep -Eqi "ubuntu"; then
    release="ubuntu"
elif cat /etc/issue | grep -Eqi "centos|red hat|redhat"; then
    release="centos"
elif cat /proc/version | grep -Eqi "debian"; then
    release="debian"
elif cat /proc/version | grep -Eqi "ubuntu"; then
    release="ubuntu"
elif cat /proc/version | grep -Eqi "centos|red hat|redhat"; then
    release="centos"
else
    echo -e "${red}Hệ Điều Hành Không Được Hỗ Trợ！${plain}\n" && exit 1
fi

os_version=""

# os version
if [[ -f /etc/os-release ]]; then
    os_version=$(awk -F'[= ."]' '/VERSION_ID/{print $3}' /etc/os-release)
fi
if [[ -z "$os_version" && -f /etc/lsb-release ]]; then
    os_version=$(awk -F'[= ."]+' '/DISTRIB_RELEASE/{print $2}' /etc/lsb-release)
fi

if [[ x"${release}" == x"centos" ]]; then
    if [[ ${os_version} -le 6 ]]; then
        echo -e "${red}Vui Lòng Sử Dụng CentOS 7 Trở Lên！${plain}\n" && exit 1
    fi
elif [[ x"${release}" == x"ubuntu" ]]; then
    if [[ ${os_version} -lt 16 ]]; then
        echo -e "${red}Vui Lòng Sử Dụng Ubuntu 16 Trở Lên！${plain}\n" && exit 1
    fi
elif [[ x"${release}" == x"debian" ]]; then
    if [[ ${os_version} -lt 8 ]]; then
        echo -e "${red}Vui Lòng Sử Dụng Debian 8 Trở Lên！${plain}\n" && exit 1
    fi
fi

confirm() {
    if [[ $# > 1 ]]; then
        echo && read -p "$1 [默认$2]: " temp
        if [[ x"${temp}" == x"" ]]; then
            temp=$2
        fi
    else
        read -p "$1 [y/n]: " temp
    fi
    if [[ x"${temp}" == x"y" || x"${temp}" == x"Y" ]]; then
        return 0
    else
        return 1
    fi
}

confirm_restart() {
    confirm "是否重启XrayR" "y"
    if [[ $? == 0 ]]; then
        restart
    else
        show_menu
    fi
}

before_show_menu() {
    echo && echo -n -e "${yellow}Nhấn enter để quay lại menu chính: ${plain}" && read temp
    show_menu
}

install() {
    bash <(curl -Ls https://raw.githubusercontent.com/Dungkobietcode/XrayR_mod/main/install.sh)
    if [[ $? == 0 ]]; then
        if [[ $# == 0 ]]; then
            start
        else
            start 0
        fi
    fi
}

update() {
    if [[ $# == 0 ]]; then
        echo && echo -n -e "Nhập phiên bản được chỉ định (mặc định là phiên bản mới nhất): " && read version
    else
        version=$2
    fi
#    confirm "本功能会强制重装当前最新版，数据不会丢失，是否继续?" "n"
#    if [[ $? != 0 ]]; then
#        echo -e "${red}已取消${plain}"
#        if [[ $1 != 0 ]]; then
#            before_show_menu
#        fi
#        return 0
#    fi
    bash <(curl -Ls https://raw.githubusercontent.com/Dungkobietcode/XrayR_mod/main/install.sh) $version
    if [[ $? == 0 ]]; then
        echo -e "${green}Quá trình cập nhật hoàn tất và XrayR đã tự động khởi động lại, vui lòng sử dụng nhật ký XrayR để xem nhật ký đang chạy${plain}"
        exit
    fi

    if [[ $# == 0 ]]; then
        before_show_menu
    fi
}

config() {
    echo "XrayR sẽ tự động thử khởi động lại sau khi sửa đổi cấu hình"
    vi /etc/XrayR/config.yml
    sleep 2
    check_status
    case $? in
        0)
            echo -e "Trạng Thái : ${green}Đã Chạy${plain}"
            ;;
        1)
            echo -e "Chúng tôi phát hiện thấy bạn chưa khởi động XrayR hoặc XrayR không tự động khởi động lại. Bạn có muốn kiểm tra nhật ký không？[Y/n]" && echo
            read -e -p "(默认: y):" yn
            [[ -z ${yn} ]] && yn="y"
            if [[ ${yn} == [Yy] ]]; then
               show_log
            fi
            ;;
        2)
            echo -e "Trạng Thái : ${red}Chưa Chạy${plain}"
    esac
}

uninstall() {
    confirm "Bạn có chắc chắn muốn gỡ cài đặt XrayR không?" "n"
    if [[ $? != 0 ]]; then
        if [[ $# == 0 ]]; then
            show_menu
        fi
        return 0
    fi
    systemctl stop XrayR
    systemctl disable XrayR
    rm /etc/systemd/system/XrayR.service -f
    systemctl daemon-reload
    systemctl reset-failed
    rm /etc/XrayR/ -rf
    rm /usr/local/XrayR/ -rf

    echo ""
    echo -e "Quá trình gỡ cài đặt thành công. Nếu bạn muốn xóa tập lệnh này, hãy thoát tập lệnh và chạy ${green}rm /usr/bin/XrayR -f${plain} Để Xóa Bỏ"
    echo ""

    if [[ $# == 0 ]]; then
        before_show_menu
    fi
}

start() {
    check_status
    if [[ $? == 0 ]]; then
        echo ""
        echo -e "${green}XrayR đã chạy và không cần phải khởi động lại. Nếu bạn cần khởi động lại, vui lòng chọn Khởi động lại.${plain}"
    else
        systemctl start XrayR
        sleep 2
        check_status
        if [[ $? == 0 ]]; then
            echo -e "${green}XrayR đã khởi động thành công, vui lòng sử dụng nhật ký XrayR để xem nhật ký đang chạy${plain}"
        else
            echo -e "${red}XrayR có thể không khởi động được, vui lòng sử dụng nhật ký XrayR sau để xem thông tin nhật ký.${plain}"
        fi
    fi

    if [[ $# == 0 ]]; then
        before_show_menu
    fi
}

stop() {
    systemctl stop XrayR
    sleep 2
    check_status
    if [[ $? == 1 ]]; then
        echo -e "${green}XrayR đã dừng thành công${plain}"
    else
        echo -e "${red}XrayR không dừng được, có thể do thời gian dừng vượt quá hai giây. Vui lòng kiểm tra thông tin nhật ký sau.${plain}"
    fi

    if [[ $# == 0 ]]; then
        before_show_menu
    fi
}

restart() {
    systemctl restart XrayR
    sleep 2
    check_status
    if [[ $? == 0 ]]; then
        echo -e "${green}XrayR đã khởi động lại thành công, vui lòng sử dụng nhật ký XrayR để xem nhật ký đang chạy${plain}"
    else
        echo -e "${red}XrayR có thể không khởi động được, vui lòng sử dụng nhật ký XrayR sau để xem thông tin nhật ký.${plain}"
    fi
    if [[ $# == 0 ]]; then
        before_show_menu
    fi
}

status() {
    systemctl status XrayR --no-pager -l
    if [[ $# == 0 ]]; then
        before_show_menu
    fi
}

enable() {
    systemctl enable XrayR
    if [[ $? == 0 ]]; then
        echo -e "${green}XrayR được thiết lập để tự động khởi động khi khởi động${plain}"
    else
        echo -e "${red}Cài đặt XrayR không tự động khởi động${plain}"
    fi

    if [[ $# == 0 ]]; then
        before_show_menu
    fi
}

disable() {
    systemctl disable XrayR
    if [[ $? == 0 ]]; then
        echo -e "${green}XrayR hủy khởi động và tự động khởi động thành công${plain}"
    else
        echo -e "${red}XrayR không hủy được tính năng tự động khởi động khởi động${plain}"
    fi

    if [[ $# == 0 ]]; then
        before_show_menu
    fi
}

show_log() {
    journalctl -u XrayR.service -e --no-pager -f
    if [[ $# == 0 ]]; then
        before_show_menu
    fi
}

install_bbr() {
    bash <(curl -L -s https://raw.githubusercontent.com/chiakge/Linux-NetSpeed/master/tcp.sh)
    #if [[ $? == 0 ]]; then
    #    echo ""
    #    echo -e "${green}安装 bbr 成功，请重启服务器${plain}"
    #else
    #    echo ""
    #    echo -e "${red}下载 bbr 安装脚本失败，请检查本机能否连接 Github${plain}"
    #fi

    #before_show_menu
}

update_shell() {
    wget -O /usr/bin/XrayR -N --no-check-certificate https://raw.githubusercontent.com/Dungkobietcode/XrayR_mod/main/XrayR.sh
    if [[ $? != 0 ]]; then
        echo ""
        echo -e "${red}Không tải được script, vui lòng kiểm tra xem VPS có kết nối được với Github không${plain}"
        before_show_menu
    else
        chmod +x /usr/bin/XrayR
        echo -e "${green}Script nâng cấp thành công, vui lòng chạy lại Script.${plain}" && exit 0
    fi
}
block(){
    bash <(curl -Ls https://raw.githubusercontent.com/AZZ-vopp/code-/main/blockspeedtest.sh)
}
# 0: running, 1: not running, 2: not installed
check_status() {
    if [[ ! -f /etc/systemd/system/XrayR.service ]]; then
        return 2
    fi
    temp=$(systemctl status XrayR | grep Active | awk '{print $3}' | cut -d "(" -f2 | cut -d ")" -f1)
    if [[ x"${temp}" == x"running" ]]; then
        return 0
    else
        return 1
    fi
}

check_enabled() {
    temp=$(systemctl is-enabled XrayR)
    if [[ x"${temp}" == x"enabled" ]]; then
        return 0
    else
        return 1;
    fi
}

check_uninstall() {
    check_status
    if [[ $? != 2 ]]; then
        echo ""
        echo -e "${red}XrayR đã được cài đặt, vui lòng không cài đặt lại${plain}"
        if [[ $# == 0 ]]; then
            before_show_menu
        fi
        return 1
    else
        return 0
    fi
}

check_install() {
    check_status
    if [[ $? == 2 ]]; then
        echo ""
        echo -e "${red}Vui lòng cài đặt XrayR trướcR${plain}"
        if [[ $# == 0 ]]; then
            before_show_menu
        fi
        return 1
    else
        return 0
    fi
}

show_status() {
    check_status
    case $? in
        0)
            echo -e "Trạng thái XrayR: ${green}Đã Chạy${plain}"
            show_enable_status
            ;;
        1)
            echo -e "Trạng thái XrayR: ${yellow}Không Chạy${plain}"
            show_enable_status
            ;;
        2)
            echo -e "Trạng Thái XrayR: ${red}Chưa Cài Đặt${plain}"
    esac
}

show_enable_status() {
    check_enabled
    if [[ $? == 0 ]]; then
        echo -e "Có khởi động tự động sau khi bật nguồn hay không: ${green}Có${plain}"
    else
        echo -e "Có khởi động tự động sau khi bật nguồn hay không ${red}Không${plain}"
    fi
}

show_XrayR_version() {
    echo -n "Phiên bản XrayR："
    /usr/local/XrayR/XrayR -version
    echo ""
    if [[ $# == 0 ]]; then
        before_show_menu
    fi
}

show_usage() {
    echo "Bảng Quản Lí XrayR: "
    echo "------------------------------------------"
    echo "XrayR              - Hiển Thị Cài Đặt XrayR"
    echo "XrayR start        - Khởi Động XrayR"
    echo "XrayR stop         - Dừng XrayR"
    echo "XrayR restart      - Khởi Động Lại XrayR"
    echo "XrayR status       - Hiển Thị Trạng Thái XrayR"
    echo "XrayR enable       - Bật Tự Khởi Động Lại XrayR"
    echo "XrayR disable      - Tắt Tự Khởi Động Lại XrayR"
    echo "XrayR log          - Hiển Thị Nhật Ký XrayR"
    echo "XrayR update       - Cập Nhật XrayR"
    echo "XrayR update x.x.x - Update XrayR Lên 1 Phiên Bản Cụ Thể"
    echo "XrayR install      - Cài Đặt XrayR"
    echo "XrayR uninstall    - GỠ Cài Đặt XrayR"
    echo "XrayR version      - Hiển Thị Phiên Bản XrayR"
    echo "------------------------------------------"
}

show_menu() {
    echo -e "
  ${green}XrayR Việt Hóa By https://github.com/dungkobietcode${plain}
--- https://github.com/dungkobietcode/XrayR_mod ---
  ${green}0.${plain} Mở Cài Đặt XrayR
————————————————
  ${green}1.${plain} Kiểm Tra XrayR Đã Cài Đặt Hay Chưa
  ${green}2.${plain} Cập Nhật Hoặc Kiểm Tra XrayR
  ${green}3.${plain} Dừng XrayR
————————————————
  ${green}4.${plain} Khởi Động Lại XrayR
  ${green}5.${plain} Trạng Thái XrayR
  ${green}6.${plain} Bật Tự Khởi Động XrayR
  ${green}7.${plain} Tắt Tự Khởi Động XrayR
  ${green}8.${plain} Hiển Thị Nhật Ký
————————————————
  ${green}9.${plain} Bật Tự Khởi động XrayR
 ${green}10.${plain} tắt Tự Khởi Động XrayR
————————————————
 ${green}11.${plain} Cài Đặt Script Bbr (phiên bản mới nhất)
 ${green}12.${plain} Gỡ Cài Đặt XrayR 
 ${green}13.${plain} Hiển Thị Phiên Bản XrayR
 ${green}14.${plain} Block Speedtest
 "
 #后续更新可加入上方字符串中
    show_status
    echo && read -p "Vui Lòng Nhập [0-13]: " num

    case "${num}" in
        0) config
        ;;
        1) check_uninstall && install
        ;;
        2) check_install && update
        ;;
        3) check_install && uninstall
        ;;
        4) check_install && start
        ;;
        5) check_install && stop
        ;;
        6) check_install && restart
        ;;
        7) check_install && status
        ;;
        8) check_install && show_log
        ;;
        9) check_install && enable
        ;;
        10) check_install && disable
        ;;
        11) install_bbr
        ;;
        12) check_install && show_XrayR_version
        ;;
        13) update_shell
        ;;
        14) block
        ;;
        *) echo -e "${red}Vui lòng nhập đúng số [0-12]${plain}"
        ;;
    esac
}


if [[ $# > 0 ]]; then
    case $1 in
        "start") check_install 0 && start 0
        ;;
        "stop") check_install 0 && stop 0
        ;;
        "restart") check_install 0 && restart 0
        ;;
        "status") check_install 0 && status 0
        ;;
        "enable") check_install 0 && enable 0
        ;;
        "disable") check_install 0 && disable 0
        ;;
        "log") check_install 0 && show_log 0
        ;;
        "update") check_install 0 && update 0 $2
        ;;
        "config") config $*
        ;;
        "install") check_uninstall 0 && install 0
        ;;
        "uninstall") check_install 0 && uninstall 0
        ;;
        "version") check_install 0 && show_XrayR_version 0
        ;;
        "update_shell") update_shell
        ;;
        "block") block
        ;;
        *) show_usage
    esac
else
    show_menu
fi
