from flask import Flask, jsonify, request
import tensorflow as tf
import numpy as np
from PIL import Image
import io, json, requests, tempfile, os

# Inisialisasi Flask
app = Flask(__name__)

# Load model dan label
MODEL_URL = "https://huggingface.co/ZenMicro/model-EffNetV2-M/resolve/main/best_stage2-V3.keras"

def download_and_load_model():
    try:
        print("⬇️ Downloading model from Hugging Face...")
        response = requests.get(MODEL_URL, stream=True)
        response.raise_for_status()

        # Simpan model ke file sementara
        with tempfile.NamedTemporaryFile(delete=False, suffix=".keras") as tmp:
            for chunk in response.iter_content(chunk_size=8192):
                if chunk:
                    tmp.write(chunk)
            tmp_path = tmp.name

        print(f"📦 Model downloaded temporarily at: {tmp_path}")

        # Load model dari file .keras
        model_loaded = tf.keras.models.load_model(tmp_path)
        print("✅ Model loaded successfully!")

        # Hapus file sementara setelah berhasil load
        os.remove(tmp_path)
        print("🧹 Temporary file removed.")

        return model_loaded
    except Exception as e:
        print(f"❌ Failed to load model: {e}")
        return None

model = download_and_load_model()

with open("assets/labels.txt", "r") as f:
    labels = [line.strip() for line in f.readlines()]

with open("assets/response.json", "r", encoding='utf-8') as f:
    disease_info = json.load(f)

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
        img = img.resize((480, 480))
        img_array = np.array(img)
        img_array = np.expand_dims(img_array, axis=0)

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