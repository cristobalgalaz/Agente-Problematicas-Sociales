from flask import Flask, jsonify, request, send_file
from flask_cors import CORS
import psycopg2
from psycopg2.extras import RealDictCursor
import json
from datetime import datetime, timedelta
import csv
import io
from dotenv import load_dotenv
import os
import requests as http_requests
import jwt

app = Flask(__name__)
CORS(app)




# Cargar variables de entorno
load_dotenv(override=True, encoding='latin-1')
# Configuración de PostgreSQL
DB_CONFIG = {
    'host': os.getenv('DB_HOST'),
    'port': int(os.getenv('DB_PORT')),
    'database': os.getenv('DB_DATABASE'),
    'user': os.getenv('DB_USER'),
    'password': os.getenv('DB_PASSWORD')
}



N8N_WEBHOOK_URL = os.getenv("N8N_WEBHOOK_URL")

def get_db_connection():
    """Obtener conexión a la base de datos"""
    try:
        conn = psycopg2.connect(**DB_CONFIG)
        return conn
    except Exception as e:
        print(f"Error conectando a PostgreSQL: {e}")
        return None


@app.route('/')
def index():
    """Servir el frontend HTML"""
    return send_file('index.html')


@app.route('/problematicas', methods=['GET'])
def get_problematicas():
    """Obtener todas las problemáticas con filtros opcionales"""
    try:
        search = request.args.get('search', '').strip()
        area_social = request.args.get('area_social', '').strip()
        area_tecnologica = request.args.get('area_tecnologica', '').strip()
        tiene_problematica = request.args.get('tiene_problematica', '').strip()

        conn = get_db_connection()
        if not conn:
            return jsonify({'error': 'Error de conexión a la base de datos'}), 500

        cursor = conn.cursor(cursor_factory=RealDictCursor)

        query = """
            SELECT 
                id,
                titulo,
                descripcion,
                area_social,
                area_tecnologica,
                solucion,
                url_fuente,
                fecha_analisis
            FROM problematicas
            WHERE 1=1
        """
        params = []

        if search:
            query += " AND (titulo ILIKE %s OR descripcion ILIKE %s OR area_social ILIKE %s)"
            search_param = f'%{search}%'
            params.extend([search_param, search_param, search_param])

        if area_social:
            query += " AND area_social ILIKE %s"
            params.append(f'%{area_social}%')

        if area_tecnologica:
            query += " AND area_tecnologica ILIKE %s"
            params.append(f'%{area_tecnologica}%')

        query += " ORDER BY fecha_analisis DESC"

        cursor.execute(query, params)
        results = cursor.fetchall()

        problematicas = []
        for row in results:
            item = dict(row)
            if item.get('fecha_analisis'):
                item['fecha_analisis'] = item['fecha_analisis'].isoformat() if hasattr(item['fecha_analisis'], 'isoformat') else str(item['fecha_analisis'])
            problematicas.append(item)

        cursor.close()
        conn.close()

        return jsonify({
            'success': True,
            'data': problematicas,
            'total': len(problematicas)
        })

    except Exception as e:
        print(f"Error: {e}")
        return jsonify({'error': str(e)}), 500


@app.route('/api/estadisticas', methods=['GET'])
def get_estadisticas():
    """Obtener estadísticas generales"""
    try:
        conn = get_db_connection()
        if not conn:
            return jsonify({'error': 'Error de conexión a la base de datos'}), 500

        cursor = conn.cursor(cursor_factory=RealDictCursor)

        cursor.execute("SELECT COUNT(*) as total FROM problematicas")
        total = cursor.fetchone()['total']

        cursor.execute("""
            SELECT area_social, COUNT(*) as cantidad 
            FROM problematicas 
            WHERE area_social IS NOT NULL AND area_social != 'N/A'
            GROUP BY area_social 
            ORDER BY cantidad DESC
            LIMIT 10
        """)
        areas_sociales = cursor.fetchall()

        cursor.execute("""
            SELECT area_tecnologica, COUNT(*) as cantidad 
            FROM problematicas 
            WHERE area_tecnologica IS NOT NULL AND area_tecnologica != 'N/A'
            GROUP BY area_tecnologica 
            ORDER BY cantidad DESC
            LIMIT 10
        """)
        areas_tecnologicas = cursor.fetchall()

        cursor.close()
        conn.close()

        return jsonify({
            'success': True,
            'data': {
                'total': total,
                'areas_sociales': [dict(row) for row in areas_sociales],
                'areas_tecnologicas': [dict(row) for row in areas_tecnologicas]
            }
        })

    except Exception as e:
        print(f"Error: {e}")
        return jsonify({'error': str(e)}), 500


@app.route('/export/csv', methods=['GET'])
def export_csv():
    """Exportar problemáticas a CSV"""
    try:
        conn = get_db_connection()
        if not conn:
            return jsonify({'error': 'Error de conexión a la base de datos'}), 500

        cursor = conn.cursor(cursor_factory=RealDictCursor)

        cursor.execute("""
            SELECT 
                id, titulo, url_fuente, descripcion, fecha_analisis, 
                area_social, area_tecnologica, solucion
            FROM problematicas
            ORDER BY fecha_analisis DESC
        """)
        results = cursor.fetchall()

        output = io.StringIO()
        writer = csv.writer(output)

        writer.writerow([
            'ID', 'Título', 'URL', 'Descripción', 'Fecha Análisis',
            'Área Social', 'Área Tecnológica', 'Solución'
        ])

        for row in results:
            writer.writerow([
                row['id'],
                row['titulo'],
                row['url_fuente'],
                row['descripcion'],
                row['fecha_analisis'],
                row['area_social'],
                row['area_tecnologica'],
                row['solucion']
            ])

        cursor.close()
        conn.close()

        output.seek(0)
        return send_file(
            io.BytesIO(output.getvalue().encode('utf-8-sig')),
            mimetype='text/csv',
            as_attachment=True,
            download_name=f'problematicas_sociales_{datetime.now().strftime("%Y%m%d_%H%M%S")}.csv'
        )

    except Exception as e:
        print(f"Error: {e}")
        return jsonify({'error': str(e)}), 500


@app.route('/areas', methods=['GET'])
def get_areas():
    """Obtener listas únicas de áreas para filtros"""
    try:
        conn = get_db_connection()
        if not conn:
            return jsonify({'error': 'Error de conexión a la base de datos'}), 500

        cursor = conn.cursor(cursor_factory=RealDictCursor)

        cursor.execute("""
            SELECT DISTINCT area_social 
            FROM problematicas 
            WHERE area_social IS NOT NULL AND area_social != 'N/A'
            ORDER BY area_social
        """)
        areas_sociales = [row['area_social'] for row in cursor.fetchall()]

        cursor.execute("""
            SELECT DISTINCT area_tecnologica 
            FROM problematicas 
            WHERE area_tecnologica IS NOT NULL AND area_tecnologica != 'N/A'
            ORDER BY area_tecnologica
        """)
        areas_tecnologicas = [row['area_tecnologica'] for row in cursor.fetchall()]

        cursor.close()
        conn.close()

        return jsonify({
            'success': True,
            'data': {
                'areas_sociales': areas_sociales,
                'areas_tecnologicas': areas_tecnologicas
            }
        })

    except Exception as e:
        print(f"Error: {e}")
        return jsonify({'error': str(e)}), 500


@app.route('/health', methods=['GET'])
def health():
    """Endpoint de salud"""
    try:
        conn = get_db_connection()
        if not conn:
            return jsonify({'status': 'unhealthy', 'database': 'disconnected'}), 500

        cursor = conn.cursor()
        cursor.execute('SELECT 1')
        cursor.close()
        conn.close()

        return jsonify({
            'status': 'healthy',
            'database': 'connected',
            'timestamp': datetime.now().isoformat()
        })
    except Exception as e:
        return jsonify({'status': 'unhealthy', 'error': str(e)}), 500


# SCRAPING MANUAL 
# 
def generar_headers_jwt(payload_extra=None):
    secret = os.getenv("WEBHOOK_TOKEN")

    if not secret:
        raise Exception("WEBHOOK_TOKEN no definido")

    payload = {
        "iat": datetime.utcnow(),
        "exp": datetime.utcnow() + timedelta(minutes=5),
    }

    if payload_extra:
        payload.update(payload_extra)

    token = jwt.encode(payload, secret, algorithm="HS256")

    return {
        "Authorization": f"Bearer {token}",
        "Content-Type": "application/json"
    }


@app.route('/api/scraping/ejecutar', methods=['POST'])
def ejecutar_scraping():
    """Disparar el flujo manual de scraping en n8n"""
    try:
        body = request.get_json() or {}
        cantidad_posts = body.get('cantidad_posts', None)
        categoria = body.get('categoria', None)

        # Registrar inicio en logs
        conn = get_db_connection()
        if not conn:
            return jsonify({'error': 'Error de conexión a la base de datos'}), 500

        cursor = conn.cursor(cursor_factory=RealDictCursor)
        cursor.execute("""
            INSERT INTO logs_ejecucion (flujo_nombre, etapa, estado, mensaje)
            VALUES ('HU-01 Manual Scraping', 'solicitud_manual', 'en_progreso',
                    'Scraping manual iniciado desde el frontend')
            RETURNING id
        """)
        log_id = cursor.fetchone()['id']
        conn.commit()
        cursor.close()
        conn.close()

        # Llamar al webhook de n8n
        payload = {
            'cantidad_posts': cantidad_posts,
            'categoria': categoria
        }
       
        headers= generar_headers_jwt({
                "source": "flask-api"
        })
        response = http_requests.post(N8N_WEBHOOK_URL, headers=headers, json=payload, timeout=400)

        if response.status_code != 200:
            print(f"n8n response: {response.status_code} - {response.text}")
            return jsonify({
                'success': False,
                'mensaje': 'Error al comunicarse con n8n',
                'detalle': response.text
                
            }), 500

        return jsonify({
            'success': True,
            'status': 'iniciado',
            'mensaje': 'El scraping ha comenzado',
            'log_id': log_id
        })

    except Exception as e:
        print(f"Error ejecutar_scraping: {e}")
        return jsonify({'error': str(e)}), 500


@app.route('/api/scraping/estado', methods=['GET'])
def estado_scraping():
    """Consultar el estado del último scraping manual"""
    try:
        conn = get_db_connection()
        if not conn:
            return jsonify({'error': 'Error de conexión a la base de datos'}), 500

        cursor = conn.cursor(cursor_factory=RealDictCursor)
        cursor.execute("""
            SELECT id, etapa, estado, mensaje, fecha_hora
            FROM logs_ejecucion
            WHERE flujo_nombre = 'HU-01 Manual Scraping'
            ORDER BY fecha_hora DESC
            LIMIT 1
        """)
        ultimo_log = cursor.fetchone()
        cursor.close()
        conn.close()

        if not ultimo_log:
            return jsonify({'success': True, 'estado': 'sin_ejecucion'})

        item = dict(ultimo_log)
        if item.get('fecha_hora'):
            item['fecha_hora'] = item['fecha_hora'].isoformat()

        return jsonify({
            'success': True,
            'estado': item['estado'],
            'data': item
        })

    except Exception as e:
        print(f"Error estado_scraping: {e}")
        return jsonify({'error': str(e)}), 500


if __name__ == '__main__':
    print("🚀 Iniciando API Flask...")
    print(f"📊 Base de datos: PostgreSQL en {DB_CONFIG['host']}:{DB_CONFIG['port']}")
    print("🌐 Servidor: servidor:5000")
    app.run(debug=False, host='0.0.0.0', port=5000)