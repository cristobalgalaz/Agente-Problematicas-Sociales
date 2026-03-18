# 🤖 Agente Inteligente - Sprint 2: Frontend

Sistema web moderno para visualizar y analizar problemáticas sociales extraídas del foro Replit Community.

## 📋 Características

### ✨ Funcionalidades principales
- **Visualización moderna**: Diseño responsivo con gradientes y animaciones
- **Búsqueda en tiempo real**: Filtra por título, contenido o problemática
- **Filtros avanzados**: Por área social y área tecnológica
- **Estadísticas**: Cards con totales y contadores
- **Modal de detalles**: Vista expandida de cada problemática
- **Favoritos**: Guarda tus posts favoritos (localStorage)
- **Exportación CSV**: Descarga todos los datos
- **Diseño responsivo**: Funciona en desktop y móvil

### 🎨 Diseño UI/UX
- Paleta de colores moderna (violeta/azul)
- Tarjetas con hover effects
- Badges de estado (problemática/ok)
- Tags de categorías
- Modal con animaciones
- Estados de carga y vacío

## 🚀 Instalación

### 1. Requisitos previos
```bash
# Python 3.8+
# PostgreSQL corriendo en localhost:5435
# Base de datos: agente_db
```

### 2. Instalar dependencias
```bash
pip install -r requirements.txt
```

### 3. Configurar base de datos
Asegúrate que PostgreSQL esté corriendo con:
- **Host**: localhost
- **Puerto**: 5435
- **Database**: agente_db
- **Usuario**: agente_user
- **Password**: agente_pass

Si tus credenciales son diferentes, edita `api.py` líneas 11-17:

```python
DB_CONFIG = {
    'host': 'localhost',
    'port': 5435,  # Tu puerto
    'database': 'agente_db',  # Tu DB
    'user': 'agente_user',  # Tu usuario
    'password': 'agente_pass'  # Tu contraseña
}
```

### 4. Verificar tabla en PostgreSQL
La API espera una tabla llamada `problematicas_sociales` con esta estructura:

```sql
CREATE TABLE problematicas_sociales (
    id INTEGER PRIMARY KEY,
    titulo TEXT NOT NULL,
    url TEXT,
    contenido TEXT,
    autor TEXT,
    fecha TIMESTAMP,
    area_social TEXT,
    area_tecnologica TEXT,
    problematica TEXT,
    solucion_sugerida TEXT,
    tiene_problematica BOOLEAN,
    tags JSONB,
    fecha_analisis TIMESTAMP DEFAULT NOW()
);
```

## 🎯 Uso

### 1. Iniciar la API
```bash
python api.py
```

Verás:
```
🚀 Iniciando API Flask...
📊 Base de datos: PostgreSQL en localhost:5435
🌐 Servidor: http://localhost:5000
```

### 2. Abrir el frontend
Abre `index.html` en tu navegador:
- Doble click en el archivo
- O arrastra a Chrome/Firefox
- O usa: `python -m http.server 8000` y ve a http://localhost:8000

### 3. Verificar conexión
La página debe cargar automáticamente los datos. Si ves errores:
1. Verifica que la API esté corriendo (http://localhost:5000/health)
2. Revisa la consola del navegador (F12)
3. Confirma que PostgreSQL esté activo

## 📡 API Endpoints

### `GET /api/problematicas`
Obtiene todas las problemáticas con filtros opcionales.

**Query params**:
- `search`: Búsqueda por texto
- `area_social`: Filtrar por área social
- `area_tecnologica`: Filtrar por área tecnológica
- `tiene_problematica`: true/false

**Ejemplo**:
```bash
curl "http://localhost:5000/api/problematicas?search=error&tiene_problematica=true"
```

### `GET /api/estadisticas`
Retorna contadores y estadísticas generales.

### `GET /api/areas`
Lista de áreas sociales y tecnológicas únicas (para filtros).

### `GET /api/export/csv`
Descarga CSV con todas las problemáticas.

### `GET /health`
Health check de la API y conexión a BD.

## 🎨 Personalización

### Cambiar colores
Edita las variables CSS en `index.html` (líneas 10-22):

```css
:root {
    --primary: #2563eb;  /* Color principal */
    --success: #10b981;  /* Verde */
    --warning: #f59e0b;  /* Amarillo */
    --danger: #ef4444;   /* Rojo */
}
```

### Cambiar URL de la API
Si la API corre en otro puerto, edita `index.html` línea 615:

```javascript
const API_URL = 'http://localhost:5000/api';  // Tu URL
```

## 🐛 Troubleshooting

### Error: "Error al cargar los datos"
- ✅ La API está corriendo en http://localhost:5000
- ✅ PostgreSQL está activo en el puerto correcto
- ✅ Las credenciales en `api.py` son correctas

### Error: CORS
Si ves errores de CORS en la consola:
1. Verifica que `flask-cors` esté instalado
2. La API ya incluye `CORS(app)` en línea 9

### Error: "relation problematicas_sociales does not exist"
Necesitas crear la tabla en PostgreSQL (ver sección 4 de Instalación).

### La página no carga datos
1. Abre http://localhost:5000/health en el navegador
2. Debe retornar: `{"status": "healthy", "database": "connected"}`
3. Si retorna error, revisa las credenciales de PostgreSQL

## 📦 Estructura del proyecto

```
proyecto/
├── api.py              # Backend Flask
├── index.html          # Frontend web
├── requirements.txt    # Dependencias Python
└── README.md          # Este archivo
```

## 🔄 Integración con n8n

Este frontend consume los datos que tu workflow de n8n inserta en PostgreSQL:

1. **n8n** → Scraping + Gemini → PostgreSQL (tabla: `problematicas_sociales`)
2. **API Flask** → Lee PostgreSQL
3. **Frontend** → Muestra datos vía API

## 📝 Tareas del Sprint 2

- [x] Diseño UI/UX moderno
- [x] Sistema de búsqueda y filtros
- [x] Cards con detalles
- [x] Modal expandido
- [x] Estadísticas en tiempo real
- [x] Exportación CSV
- [x] Sistema de favoritos
- [x] Responsive design
- [ ] Gráficos (opcional para Sprint 3)
- [ ] Autenticación (opcional para Sprint 3)

## 👨‍💻 Desarrollo

Creado para el proyecto "Agente Inteligente de Identificación de Problemáticas Sociales" - UNAB 2026

---

¿Problemas? Revisa los logs de la API en la terminal donde ejecutaste `python api.py`.
