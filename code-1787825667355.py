from flask import Flask, request, jsonify
import requests
from threading import Thread, Timer
import time

app = Flask(__name__)

# =========================== 🛠️ 1. 免费告警通道配置：Telegram Bot ===========================
# 💡 请替换为你自己的真实 Telegram Bot 信息
# ⚠️ 免费零成本！在 Telegram 上搜索 @BotFather 创建机器人即可获得 Token
# ⚠️ 然后让机器人加入一个只有你和机器人的群组，获取 Chat ID。
# 保护隐私：这些信息在上传到 GitHub 之前应留空，避免暴露。
TELEGRAM_BOT_TOKEN = "YOUR_TELEGRAM_BOT_TOKEN_HERE"
FAMILY_CHAT_ID = "YOUR_CHAT_ID_HERE"

# 用于记录当前的吃药倒计时任务
current_timer_task = None
# ===========================================================================================


# 功能 A: 向 Telegram 发送紧急告警通知
def send_telegram_alert(patient_name, med_name):
    print(f"🚨🚨🚨 长辈吃药已超时 15 分钟，立刻向 Telegram 发送报警信息！🚨🚨🚨")
    
    msg_text = f"🚨 【紧急吃药提醒告警】\n\n"\
               f"长辈姓名：{patient_name}\n"\
               f"设定吃药：{med_name}\n"\
               f"状态：已超时 15 分钟未在手机上确认吃药！请家属立即电话联系关注！"
               
    url = f"https://api.telegram.org/bot{TELEGRAM_BOT_TOKEN}/sendMessage"
    payload = {
        "chat_id": FAMILY_CHAT_ID,
        "text": msg_text,
        "parse_mode": "MarkdownV2" # 支持文本加粗加红显示
    }
    
    try:
        response = requests.post(url, json=payload, timeout=10)
        if response.statusCode == 200:
            print("✅ Telegram 报警信息发送成功！")
        else:
            print(f"❌ 发送 Telegram 失败 (错误码: {response.statusCode}): {response.text}")
    except Exception as e:
        print(f"❌ 后端向 Telegram 发送报警出错: {e}")


# 功能 B: 开启一个后台倒计时线程，默认 15 分钟（900秒）后触发告警
def start_medication_timer(patient_name, med_name, timeout_seconds=900):
    global current_timer_task
    
    # 开启一个单独的 Timer 线程，在 timeout_seconds 秒后运行 send_telegram_alert 函数
    current_timer_task = Timer(timeout_seconds, send_telegram_alert, args=(patient_name, med_name))
    current_timer_task.start()
    print(f"☁️ 云端倒计时已启动：将在 {timeout_seconds} 秒内等待爸爸点击吃药确认按钮。")


# ============================== 🛠️ 2. API 接口配置 ==============================

# 接口 B: Flutter APP 端触发：通知后端开始 15 分钟倒计时
@app.route('/trigger-reminder', methods=['POST'])
def trigger_reminder():
    data = request.json or {}
    patient_name = data.get("patient_name", "爸爸")
    med_name = data.get("med_name", "降压药")
    
    print(f"App 到了定时提醒点，通知云端开始监控 {patient_name} 的吃药状态。")
    
    # 开始云端计时线程
    Thread(target=start_medication_timer, args=(patient_name, med_name)).start()
    
    return jsonify({"status": "Reminder timer started"}), 200


# 接口 C: Flutter APP 端触发：长辈点击“已吃药”大按钮，告诉后端取消告警
@app.route('/confirm-medication', methods=['POST'])
def confirm_medication():
    global current_timer_task
    print(f"爸爸在手机上点击了“点这里：我吃过药了”，云端同步取消告警计时任务。")
    
    if current_timer_task:
        current_timer_task.cancel() # 取消 Timer 任务，不会再发送 Telegram
        print("☁️ ✅ 云端计时已安全取消，爸爸真棒。")
    
    return jsonify({"status": "Confirmed, alarm cancelled"}), 200


# 功能 E: 本地测试运行后端
if __name__ == '__main__':
    print("--------------------------------------------------")
    print("长辈免费吃药报警系统 Python 后端已启动。")
    print("请确保已配置 Telegram Bot Token 和 Chat ID。")
    print("--------------------------------------------------")
    # 如果通过局域网连接真机测试，host 必须设为 '0.0.0.0'，端口 5000
    app.run(host='0.0.0.0', port=5000, debug=False)