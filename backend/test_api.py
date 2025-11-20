import requests

# URL endpoint Flask
url = "http://127.0.0.1:5000/predict"

# Gambar daun padi yang mau diuji
files = {'file': open('image.png', 'rb')}

# Kirim POST request
response = requests.post(url, files=files)

# Tampilkan hasil
print(response.json())
