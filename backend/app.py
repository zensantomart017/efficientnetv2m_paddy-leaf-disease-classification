from flask import Flask, jsonify, request
import tensorflow as tf
import numpy as np
from PIL import Image
import io, json, requests, tempfile, os
from flask_cors import CORS
import cv2

# Inisialisasi Flask
app = Flask(__name__)
CORS(app)

# Load model dan label
MODEL_PATH = "models/best_ft-optuna.keras"

print("🔍 Loading model dari lokal...")
try:
    model = tf.keras.models.load_model(MODEL_PATH)
    print("✅ Model berhasil dimuat dari lokal!")
except Exception as e:
    print(f"❌ Gagal load model: {e}")
    model = None

with open("assets/labels.txt", "r") as f:
    labels = [line.strip() for line in f.readlines()]

with open("assets/response.json", "r", encoding='utf-8') as f:
    disease_info = json.load(f)

def is_rice_leaf(img):
    hsv = cv2.cvtColor(img, cv2.COLOR_RGB2HSV)
    h, s, v = hsv[:,:,0], hsv[:,:,1], hsv[:,:,2]

    green_mask = (
        (h >= 35) & (h <= 85) &   # hijau yg lebih spesifik
        (s >= 40) &               # saturasi tinggi, bukan hijau plastik
        (v >= 40)                 # tidak terlalu gelap
    )

    green_pixels = np.sum(green_mask)
    total_pixels = img.shape[0] * img.shape[1]
    ratio = green_pixels / total_pixels

    print("green ratio:", ratio)
    return ratio > 0.25   # minimal 25% hijau

# Endpoint utama
@app.route('/')
def home():
    return jsonify({
        "message": "Rice Leaf Disease Detection API aktif 🚀",
        "available_endpoint": "/predict"
    })

# Endpoint prediksi
@app.route('/predict', methods=['POST'])
def predict():
    if 'file' not in request.files:
        return jsonify({
            "error": "Tidak ada file yang diunggah"
        }), 400
    
    file = request.files['file']

    try:
        # baca dan konversi gambar
        img = Image.open(io.BytesIO(file.read())).convert('RGB')
        img_np = np.array(img)

        if not is_rice_leaf(img_np):
            return jsonify({
                "label": "Unknown",
                "confidence": 0.0,
                "name": "Tidak dikenali",
                "description": "Gambar bukan daun padi.",
                "prevention": "-",
                "treatment": "-"
            })
        
        img_resized = img.resize((480, 480))
        img_array = np.expand_dims(np.array(img_resized), axis=0)

        # inferensi model
        preds = model.predict(img_array)[0]
        idx = np.argmax(preds)
        confidence = float(preds[idx])
        label = labels[idx]

        # Mapping label ke nama tampil
        label_map = {
            "bacterial_leaf_blight": "Hawar Daun Bakteri",
            "brown_spot": "Bercak Coklat",
            "healthy": "Daun Sehat",
            "leaf_blast": "Blas Daun",
            "narrow_brown_spot": "Bercak Daun Coklat Sempit",
            "sheath_blight": "Hawar Pelepah Daun"
        }

        display_label = label_map.get(label, label.replace("_", " ").title())

        # ambil informasi penyakit
        info = next((x for x in disease_info if x["name"].lower() == display_label.lower()), None)

        # kirim hasil
        return jsonify({
            "label": display_label,
            "confidence": round(confidence, 3),
            "name": info["name"] if info else "-",
            "description": info["description"] if info else "-",
            "prevention": info["prevention"] if info else "-",
            "treatment": info["treatment"] if info else "-"
        })
    
    except Exception as e:
        return jsonify({
            "error": f"Gagal memproses gambar: {str(e)}"
        }), 500

# Jalankan server
if __name__ == '__main__':
    app.run(host='0.0.0.0', port=5000, debug=True)