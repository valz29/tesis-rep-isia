"""Create the Retinazo component diagram as matching SVG and PNG files.

This is a documentation artifact, generated from project versions verified on
2026-11-12. Pillow renders the PNG; the SVG remains editable without raster text.
"""

from html import escape
from math import atan2, cos, sin
from pathlib import Path
import shutil

from PIL import Image, ImageDraw, ImageFont


ROOT = Path(__file__).resolve().parent
WIDTH, HEIGHT = 3600, 2600
BG = "#f5f9f8"
INK = "#183c3b"
MUTED = "#52716e"
GREEN = "#087f70"
TEAL = "#06635f"
BLUE = "#246b9e"
ORANGE = "#c56c13"
LINE = "#cbded8"
FONT_DIR = Path("/usr/share/fonts/truetype/dejavu")
canvas = Image.new("RGB", (WIDTH, HEIGHT), BG)
draw = ImageDraw.Draw(canvas)
svg = [
    f'<svg xmlns="http://www.w3.org/2000/svg" width="{WIDTH}" '
    f'height="{HEIGHT}" viewBox="0 0 {WIDTH} {HEIGHT}">',
    '<title>Retinazo: componentes y responsabilidades</title>',
    '<desc>Flutter con Dart usa Supabase Auth y PostgreSQL. FastAPI, alojado '
    'en Render, valida el acceso y usa Boto3 para almacenar imágenes en '
    'Cloudflare R2. La aplicación descarga imágenes con enlaces firmados.</desc>',
    f'<rect width="{WIDTH}" height="{HEIGHT}" fill="{BG}"/>',
]


def font(size, bold=False):
    name = "DejaVuSans-Bold.ttf" if bold else "DejaVuSans.ttf"
    return ImageFont.truetype(str(FONT_DIR / name), size)


def rect(x, y, w, h, fill, outline=None, radius=0, width=2):
    draw.rounded_rectangle(
        (x, y, x + w, y + h), radius, fill=fill, outline=outline, width=width
    )
    svg.append(
        f'<rect x="{x}" y="{y}" width="{w}" height="{h}" rx="{radius}" '
        f'fill="{fill}" stroke="{outline or "none"}" stroke-width="{width}"/>'
    )


def line(points, color=GREEN, width=6, dash=False):
    if dash:
        for start, end in zip(points, points[1:]):
            dx, dy = end[0] - start[0], end[1] - start[1]
            distance = (dx * dx + dy * dy) ** 0.5
            for offset in range(0, int(distance), 27):
                a, b = offset / distance, min(offset + 15, distance) / distance
                draw.line(
                    ((start[0] + dx * a, start[1] + dy * a),
                     (start[0] + dx * b, start[1] + dy * b)),
                    fill=color, width=width,
                )
    else:
        draw.line(points, fill=color, width=width, joint="curve")
    coords = " ".join(f"{x},{y}" for x, y in points)
    svg.append(
        f'<polyline points="{coords}" fill="none" stroke="{color}" '
        f'stroke-width="{width}" stroke-linejoin="round" '
        f'{"stroke-dasharray=\"15 12\"" if dash else ""}/>'
    )


def arrow(points, color=GREEN, both=False, dash=False):
    line(points, color=color, dash=dash)

    def head(tip, previous):
        angle = atan2(tip[1] - previous[1], tip[0] - previous[0])
        polygon = [tip]
        for delta in (-0.48, 0.48):
            polygon.append((tip[0] - 24 * cos(angle + delta),
                            tip[1] - 24 * sin(angle + delta)))
        draw.polygon(polygon, fill=color)
        coords = " ".join(f"{x:.1f},{y:.1f}" for x, y in polygon)
        svg.append(f'<polygon points="{coords}" fill="{color}"/>')

    head(points[-1], points[-2])
    if both:
        head(points[0], points[1])


def text(x, y, value, size=34, bold=False, color=INK):
    draw.text((x, y), value, font=font(size, bold), fill=color, anchor="lt")
    weight = "700" if bold else "400"
    svg.append(
        f'<text x="{x}" y="{y + size * .82:.1f}" '
        f'font-family="DejaVu Sans, sans-serif" font-size="{size}" '
        f'font-weight="{weight}" fill="{color}">{escape(value)}</text>'
    )


def paragraph(x, y, value, max_width, size=32, bold=False, color=INK, gap=1.42):
    words = value.split()
    current = ""
    lines = []
    for word in words:
        candidate = f"{current} {word}".strip()
        if draw.textlength(candidate, font=font(size, bold)) > max_width:
            if not current:
                raise ValueError(f"Word cannot fit in text box: {word}")
            lines.append(current)
            current = word
        else:
            current = candidate
    if current:
        lines.append(current)
    for index, row in enumerate(lines):
        text(x, y + index * size * gap, row, size, bold, color)
    return y + len(lines) * size * gap


def bullet(x, y, value, max_width, size=33):
    rect(x, y + 10, 9, 9, GREEN, radius=4)
    return paragraph(x + 28, y, value, max_width - 28, size=size)


def label(x, y, rows, color=GREEN, max_width=540):
    height = len(rows) * 44 + 30
    rect(x - 15, y - 15, max_width + 30, height, BG, radius=14)
    for index, row in enumerate(rows):
        text(x, y + index * 44, row, 30, index == 0, color)


def card(x, y, w, h, title, subtitle, accent=GREEN, icon=""):
    rect(x, y + 9, w, h, "#e1ece8", radius=30)
    rect(x, y, w, h, "#ffffff", LINE, radius=30, width=3)
    rect(x, y, w, 160, accent, radius=30)
    rect(x, y + 110, w, 50, accent)
    if icon:
        rect(x + 30, y + 31, 82, 82, "#ffffff", radius=19)
        text(x + 45, y + 55, icon, 30, True, accent)
    offset = 140 if icon else 38
    text(x + offset, y + 32, title, 47, True, "#ffffff")
    text(x + offset, y + 99, subtitle, 29, False, "#e0f6ee")


def rationale(x, y, w, value, tint="#edf7f3", size=30):
    rect(x, y, w, 174, tint, radius=18)
    text(x + 26, y + 20, "POR QUÉ SE ELIGIÓ", 24, True, GREEN)
    paragraph(x + 26, y + 64, value, w - 52, size=size)


# Title and scope.
text(100, 65, "Retinazo", 78, True, TEAL)
text(505, 79, "Componentes y responsabilidades", 65, True)
text(103, 177, "Arquitectura implementada · aplicación móvil, identidad, datos y almacenamiento", 35, color=MUTED)
line([(100, 247), (3500, 247)], color=LINE, width=3)

# Flutter: the mobile client is a runtime component; Dart is its language.
card(100, 300, 1320, 850, "Flutter · Dart", "Flutter 3.47.2  |  Dart 3.13.2", icon="UI")
text(142, 500, "APLICACIÓN MÓVIL", 26, True, GREEN)
y = 557
for item in (
    "Vistas, formularios y navegación escritos en Dart.",
    "Acceso, registro, pacientes e historial de evaluaciones.",
    "Cámara o galería: tres imágenes de un mismo ojo.",
    "Controladores y casos de uso separados de los datos.",
):
    y = bullet(144, y, item, 1220) + 18
text(144, 824, "Bibliotecas del cliente", 27, True, MUTED)
text(144, 870, "supabase_flutter 2.18.3 · image_picker 1.2.3 · http 1.6.0", 29)
rationale(140, 936, 1240,
          "Permite compartir el código móvil y acceder a funciones del teléfono, con una interfaz consistente.")

# Supabase: Auth is separate from the app's structured relational data.
card(2050, 300, 1450, 850, "Supabase", "Plataforma gestionada: identidad + PostgreSQL", icon="SB")
rect(2085, 500, 650, 610, "#f7fbf9", LINE, radius=20)
rect(2770, 500, 695, 610, "#f7fbf9", LINE, radius=20)
text(2110, 530, "Supabase Auth", 37, True, GREEN)
text(2110, 584, "Servicio gestionado", 27, color=MUTED)
y = 650
for item in ("Crea y verifica cuentas.", "Confirma el correo electrónico.",
             "Gestiona contraseñas y sesión.", "Emite tokens de acceso JWT."):
    y = bullet(2110, y, item, 598, 28) + 13
text(2110, 921, "POR QUÉ SE ELIGIÓ", 23, True, GREEN)
paragraph(2110, 964, "Resuelve la identidad sin desarrollar un sistema de autenticación propio.", 590, 27)

text(2795, 530, "PostgreSQL 17.11", 37, True, GREEN)
text(2795, 584, "Base de datos en Supabase", 27, color=MUTED)
y = 650
for item in ("Perfiles y roles: profiles.", "Pacientes: patients.",
             "Evaluaciones y metadatos.", "Relaciones y permisos RLS."):
    y = bullet(2795, y, item, 640, 28) + 13
text(2795, 866, "profiles se vincula con auth.users", 26, True)
text(2795, 921, "POR QUÉ SE ELIGIÓ", 23, True, GREEN)
paragraph(2795, 964, "Los datos tienen relaciones, integridad y permisos por fila. Los archivos van en R2.", 635, 27)

# Cloudflare stores objects, while boto3 runs in the Python API process.
card(100, 1610, 1320, 720, "Cloudflare R2", "Almacenamiento de objetos · bucket privado", accent=ORANGE, icon="R2")
y = 1810
for item in ("Guarda las imágenes originales JPEG/PNG.",
             "Bucket de la aplicación: retinazo-retinas.",
             "API compatible con S3 y enlaces de lectura firmados."):
    y = bullet(144, y, item, 1220, 32) + 15
text(144, 2012, "Boto3 se ejecuta en FastAPI; R2 recibe las operaciones S3.", 29, True, ORANGE)
rationale(140, 2115, 1240,
          "Separa archivos y datos relacionales. Ofrece compatibilidad S3 y almacenamiento sin publicar el bucket.",
          tint="#fff4e7", size=29)

# FastAPI is deployed in a Docker web service on Render.
card(2050, 1610, 1450, 720, "FastAPI 0.162.0", "Alojado en Render · contenedor Docker · Python 3.12", accent=TEAL, icon="API")
y = 1810
for item in ("Valida la sesión de Supabase y el acceso a la evaluación.",
             "Comprueba las tres imágenes, su formato, tamaño e integridad.",
             "Guarda en R2 con Boto3 y confirma sus referencias en SQL.",
             "Entrega enlaces temporales para consultar las imágenes."):
    y = bullet(2094, y, item, 1350, 30) + 12
text(2094, 2050, "Boto3 1.43.124 · Uvicorn 0.54.0 · HTTPX 0.28.1 · Pillow 12.3.0", 26, True)
rationale(2090, 2115, 1370,
          "Python facilita la futura integración del modelo. Render ejecuta la API en la nube sin depender de tu PC.", size=29)

# Component links: labels indicate responsibilities, not sequence steps.
arrow([(1420, 675), (2050, 675)], both=True)
label(1480, 508, ["supabase_flutter", "Cuentas, sesión y", "datos estructurados"], max_width=500)
text(1500, 705, "HTTPS · JWT · RLS", 27, color=MUTED)

arrow([(1420, 1070), (2050, 1665)], color=TEAL, both=True)
label(1497, 1275, ["HTTPS + JWT", "Subida de 3 imágenes;", "consulta de enlaces"], color=TEAL, max_width=505)

arrow([(2775, 1610), (2775, 1150)], both=True)
label(2825, 1280, ["Verifica identidad", "y permisos; confirma", "metadatos de imágenes"], max_width=570)

arrow([(2050, 1935), (1420, 1935)], color=ORANGE, both=True)
label(1475, 1760, ["Boto3 · API S3", "Escritura y lectura", "de objetos privados"], color=ORANGE, max_width=500)

arrow([(760, 1610), (760, 1150)], color=BLUE, dash=True)
label(154, 1270, ["Lectura directa por HTTPS", "con URL temporal firmada", "generada por FastAPI"], color=BLUE, max_width=545)

# Notes make versions and implementation boundaries explicit.
rect(100, 2390, 3400, 150, "#e7f1ed", radius=22)
text(135, 2415, "Estado: usuarios, pacientes y almacenamiento implementados. Integración del modelo de IA pendiente.", 31, True, TEAL)
text(135, 2466, "Versiones del proyecto verificadas al 12/11/2026. Supabase, Auth, R2 y Render son servicios gestionados sin una versión única.", 27, color=MUTED)
svg.append("</svg>")

png_path = ROOT / "retinazo-componentes-responsabilidades.png"
svg_path = ROOT / "retinazo-componentes-responsabilidades.svg"
canvas.save(png_path, optimize=True, dpi=(240, 240))
svg_path.write_text("\n".join(svg), encoding="utf-8")
downloads = Path.home() / "Descargas"
downloads.mkdir(exist_ok=True)
for path in (png_path, svg_path):
    shutil.copy2(path, downloads / path.name)
print(png_path)
print(svg_path)
