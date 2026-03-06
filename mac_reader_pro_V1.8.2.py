import os
import time
import threading
import subprocess
import rumps
import sounddevice as sd
from pynput import keyboard
import sys
import shutil
import soundfile as sf
import numpy as np
from PIL import Image
from datetime import datetime
import tempfile 
from scipy import signal

# --- NUEVOS IMPORTS ---
import tkinter as tk
from tkinter import filedialog
from pdf2image import convert_from_path 
import fitz  # NUEVO: PyMuPDF (pip install pymupdf) para EPUB/MOBI
# ----------------------

# Librería de Traducción
from deep_translator import GoogleTranslator

# NLP & TTS
from misaki.espeak import EspeakG2P
from kokoro_onnx import Kokoro
from ocrmac import ocrmac

# --- CONFIGURACIÓN VISUAL ---
ICON_IDLE = "👓"
ICON_THINKING = "👓 💭"
ICON_SPEAKING = "👓 🔊"
ICON_ERROR = "👓 ⚠️"
ICON_SAVING = "👓 💾"
ICON_MERGING = "👓 🌪️"
ICON_BATCH = "👓 📦"
ICON_PDF = "👓 📄"
ICON_EPUB = "👓 📚"

class ProjectManager:
    def __init__(self):
        self.base_dir = os.path.expanduser("~/Documents/KokoroLibrary")
        if not os.path.exists(self.base_dir):
            os.makedirs(self.base_dir)
        
        self.current_project = "General"
        self.ensure_project_exists(self.current_project)

    def get_projects(self):
        return sorted([d for d in os.listdir(self.base_dir) 
                if os.path.isdir(os.path.join(self.base_dir, d))])

    def ensure_project_exists(self, project_name):
        path = os.path.join(self.base_dir, project_name)
        if not os.path.exists(path):
            os.makedirs(path)

    def set_project(self, project_name):
        self.current_project = project_name
        self.ensure_project_exists(project_name)

    def get_next_sequence_number(self, project_path):
        max_num = 0
        try:
            files = os.listdir(project_path)
            for f in files:
                name, _ = os.path.splitext(f)
                if name.isdigit():
                    num = int(name)
                    if num > max_num: max_num = num
        except: pass
        return max_num + 1

    def save_entry(self, text, audio_samples, sample_rate, image_path=None):
        project_path = os.path.join(self.base_dir, self.current_project)
        next_id = self.get_next_sequence_number(project_path)
        filename_str = f"{next_id:03d}"
        base_filename = os.path.join(project_path, filename_str)

        timestamp_readable = datetime.now().strftime("%Y-%m-%d %H:%M:%S")
        content_with_meta = f"--- Captura: {timestamp_readable} ---\n\n{text}"
        
        with open(f"{base_filename}.txt", "w", encoding="utf-8") as f:
            f.write(content_with_meta)

        sf.write(f"{base_filename}.wav", audio_samples, sample_rate)

        if image_path and os.path.exists(image_path):
            shutil.copy(image_path, f"{base_filename}.png")
            
        return filename_str

    def get_files_in_project(self, project_name, limit=30):
        path = os.path.join(self.base_dir, project_name)
        items = []
        try:
            files = [f for f in os.listdir(path) if f.endswith(".txt") and f[:3].isdigit()]
            files.sort(reverse=True)
            
            for f in files[:limit]:
                fid = os.path.splitext(f)[0]
                full_p = os.path.join(path, f)
                try:
                    with open(full_p, "r", encoding="utf-8") as tf:
                        txt = tf.read()
                        clean = txt.split("\n\n")[-1] if "\n\n" in txt else txt
                        snippet = (clean[:25] + '...') if len(clean) > 25 else clean
                        
                        items.append({
                            "type": "file",
                            "id": fid,
                            "label": f"📄 {fid} | {snippet}",
                            "full_text": clean,
                            "audio": os.path.join(path, f"{fid}.wav"),
                            "folder": path
                        })
                except: continue
        except: pass
        return items

    def get_merge_folders(self, project_name):
        path = os.path.join(self.base_dir, project_name)
        folders = []
        try:
            items = os.listdir(path)
            for i in items:
                full_p = os.path.join(path, i)
                if os.path.isdir(full_p) and i.startswith("Fusion_"):
                    folders.append(i)
            folders.sort(reverse=True)
        except: pass
        return folders

    def create_merge(self):
        project_path = os.path.join(self.base_dir, self.current_project)
        existing_merges = self.get_merge_folders(self.current_project)
        if not existing_merges:
            next_idx = 1
        else:
            try:
                last = existing_merges[0]
                num = int(last.split("_")[1])
                next_idx = num + 1
            except: next_idx = 1
            
        merge_folder_name = f"Fusion_{next_idx:03d}"
        merge_path = os.path.join(project_path, merge_folder_name)
        os.makedirs(merge_path)

        all_files = sorted([f for f in os.listdir(project_path) if f[:3].isdigit()])
        txt_files = [f for f in all_files if f.endswith(".txt")]
        wav_files = [f for f in all_files if f.endswith(".wav")]
        img_files = [f for f in all_files if f.endswith(".png")]

        if not txt_files: return None

        full_text_content = f"PROYECTO: {self.current_project}\nFUSIÓN: {merge_folder_name}\nFECHA: {datetime.now()}\n{'='*40}\n\n"
        for tf in txt_files:
            with open(os.path.join(project_path, tf), "r", encoding="utf-8") as f:
                content = f.read()
                clean_content = content.split("\n\n")[-1] if "\n\n" in content else content
                full_text_content += f"--- SECCIÓN {tf[:3]} ---\n{clean_content}\n\n"
        
        with open(os.path.join(merge_path, "documento_completo.txt"), "w", encoding="utf-8") as f:
            f.write(full_text_content)

        audio_arrays = []
        sample_rate = 24000
        
        for wf in wav_files:
            try:
                data, sr = sf.read(os.path.join(project_path, wf))
                sample_rate = sr
                audio_arrays.append(data)
                silence = np.zeros(int(sr * 0.5))
                audio_arrays.append(silence)
            except: pass
            
        if audio_arrays:
            combined_audio = np.concatenate(audio_arrays)
            sf.write(os.path.join(merge_path, "audio_completo.wav"), combined_audio, sample_rate)

        image_list = []
        for img_f in img_files:
            try:
                img = Image.open(os.path.join(project_path, img_f)).convert('RGB')
                image_list.append(img)
            except: pass
            
        if image_list:
            pdf_path = os.path.join(merge_path, "imagenes.pdf")
            image_list[0].save(pdf_path, save_all=True, append_images=image_list[1:])

        return merge_folder_name


class KokoroBarApp(rumps.App):
    def __init__(self):
        super(KokoroBarApp, self).__init__(ICON_IDLE)
        self.pm = ProjectManager()
        
        self.projects_menu_item = rumps.MenuItem("📂 Proyectos (Explorar)")
        self.update_projects_structure()

        self.menu = [
            "📷 Capturar Pantalla (Cmd+Alt+A)",
            None,
            "🖼️ Procesar Batch de Imágenes...",
            "🖼️🌪️ Batch + Fusionar Automático...",
            None,
            "📄🌪️ PDF a Audio (Batch + Merge)...",
            "📚🌪️ EPUB a Audio (Batch + Merge)...", # NUEVO: EPUB
            None,
            "📝 Leer Selección (Cmd+Alt+S)",
            "🇬🇧 Traducir Selección EN -> ES (Cmd+Ctrl+T)",
            "🇪🇸 Traducir Selección ES -> EN",
            None,
            self.projects_menu_item,
            None,
            "📂 Abrir Carpeta en Finder",
            "⛔ Detener Audio (Cmd+Alt+Q)",
            None, 
            "Cargando modelos..." 
        ]
        
        self.is_loading = True
        self.is_playing = False
        self.keys_pressed = set()
        self.title = ICON_THINKING
        
        threading.Thread(target=self.load_models).start()
        
        self.listener = keyboard.Listener(on_press=self.on_press, on_release=self.on_release)
        self.listener.start()
        print(f"\n--- 🚀 APP INICIADA: {ICON_IDLE} ---\n") 

    # --- SELECTOR DE ARCHIVOS ROBUSTO ---
    def select_files_mac(self, mode="images"):
        """
        mode: 'images', 'pdf', o 'epub'
        """
        print(f"📂 Abriendo selector ({mode}) en subproceso...")
        try:
            # Configuración según tipo
            if mode == 'pdf':
                filetypes = '[("Archivos PDF", "*.pdf")]'
                title = "Selecciona un archivo PDF"
                cmd = "filedialog.askopenfilename"
            elif mode == 'epub':
                filetypes = '[("Ebooks", "*.epub *.mobi *.fb2")]'
                title = "Selecciona un Ebook (EPUB)"
                cmd = "filedialog.askopenfilename"
            else:
                filetypes = '[("Imágenes", "*.png *.jpg *.jpeg *.tiff *.bmp *.webp")]'
                title = "Selecciona imágenes"
                cmd = "filedialog.askopenfilenames"

            script_selector = f"""
import tkinter as tk
from tkinter import filedialog
import sys

root = tk.Tk()
root.withdraw()
root.attributes('-topmost', True) 
try:
    result = {cmd}(
        title="{title}",
        filetypes={filetypes}
    )
    if isinstance(result, tuple) or isinstance(result, list):
        print("|".join(result))
    else:
        print(result)
except:
    pass
"""
            resultado = subprocess.check_output(
                [sys.executable, "-c", script_selector],
                stderr=subprocess.STDOUT
            ).decode('utf-8').strip()

            if not resultado: return []
            
            if mode == 'pdf' or mode == 'epub':
                return [resultado] 
            else:
                return resultado.split("|")

        except Exception as e:
            print(f"❌ Error al lanzar el subproceso: {e}")
            return []

    def update_projects_structure(self):
        projects = self.pm.get_projects()
        current_proj = self.pm.current_project
        new_items = []
        
        # 1. Construir la lista de proyectos
        for p in projects:
            is_active = (p == current_proj)
            mark = "🟢" if is_active else "📁"
            project_item = rumps.MenuItem(f"{mark} {p}")
            
            if not is_active:
                activate_btn = rumps.MenuItem("📌 Activar este proyecto", callback=self.on_activate_project)
                activate_btn.project_name = p
                project_item.add(activate_btn)
            else:
                project_item.add(rumps.MenuItem("✅ Proyecto Activo", callback=None))
            
            merge_btn = rumps.MenuItem("🌪️ Fusionar Todo (Merge)", callback=self.on_merge_project)
            merge_btn.project_name = p
            project_item.add(merge_btn)
            project_item.add(None)

            # Submenú de fusiones
            merge_folders = self.pm.get_merge_folders(p)
            if merge_folders:
                for mf in merge_folders:
                    mf_menu = rumps.MenuItem(f"📚 {mf}")
                    path_merged = os.path.join(self.pm.base_dir, p, mf)
                    
                    audio_p = os.path.join(path_merged, "audio_completo.wav")
                    if os.path.exists(audio_p):
                        audio_item = rumps.MenuItem("🔊 Reproducir Audio Completo", callback=self.on_play_merge)
                        audio_item.audio_path = audio_p
                        mf_menu.add(audio_item)

                    text_p = os.path.join(path_merged, "documento_completo.txt")
                    if os.path.exists(text_p):
                        txt_item = rumps.MenuItem("📄 Ver Documento Texto", callback=self.on_open_file)
                        txt_item.file_path = text_p
                        mf_menu.add(txt_item)

                    pdf_p = os.path.join(path_merged, "imagenes.pdf")
                    if os.path.exists(pdf_p):
                        pdf_item = rumps.MenuItem("🖼️ Ver PDF Imágenes", callback=self.on_open_file)
                        pdf_item.file_path = pdf_p
                        mf_menu.add(pdf_item)
                        
                    folder_item = rumps.MenuItem("📂 Abrir Carpeta Fusión", callback=self.on_open_file)
                    folder_item.file_path = path_merged
                    mf_menu.add(folder_item)

                    project_item.add(mf_menu)
                
                project_item.add(None)

            # Archivos individuales
            files = self.pm.get_files_in_project(p)
            if not files:
                project_item.add(rumps.MenuItem("   (Archivos vacíos)", callback=None))
            else:
                for f in files:
                    file_item = rumps.MenuItem(f["label"], callback=self.on_file_click)
                    file_item.file_data = f
                    project_item.add(file_item)
            
            new_items.append(project_item)
            
        # 2. Agregar el separador y el botón de crear al final de la lista temporal
        new_items.append(None) 
        new_items.append(rumps.MenuItem("➕ Crear Nuevo Proyecto...", callback=self.on_create_project))

        # 3. ACTUALIZACIÓN SEGURA (Corrección del Crash)
        if hasattr(self, 'projects_menu_item'):
            # IMPORTANTE: Solo hacemos .clear() si el menú interno (_menu) ya existe y no es None.
            # Esto evita el AttributeError al iniciar la app.
            if hasattr(self.projects_menu_item, '_menu') and self.projects_menu_item._menu is not None:
                self.projects_menu_item.clear()
            
            # Reconstruimos el menú ítem por ítem
            for item in new_items:
                if item is None:
                    self.projects_menu_item.add(rumps.separator)
                else:
                    self.projects_menu_item.add(item)

    def on_merge_project(self, sender):
        proj = sender.project_name
        self.set_state(ICON_MERGING)
        print(f"🌪️ Iniciando fusión para: {proj}")
        
        def _bg_merge():
            folder_name = self.pm.create_merge()
            if folder_name:
                rumps.notification("Kokoro Reader", "Fusión Completada", f"Creada carpeta: {folder_name}")
            else:
                rumps.notification("Kokoro Reader", "Aviso", "No había archivos para fusionar.")
            rumps.timer(0.1)(lambda _: self.update_projects_structure())
            self.set_state(ICON_IDLE)

        threading.Thread(target=_bg_merge).start()

    def on_play_merge(self, sender):
        path = sender.audio_path
        if not os.path.exists(path): return
        
        self.set_state(ICON_SPEAKING)
        self.is_playing = True
        
        def _play():
            try:
                data, fs = sf.read(path)
                sd.play(data, fs)
                sd.wait()
            except: pass
            self.is_playing = False
            self.set_state(ICON_IDLE)
        
        threading.Thread(target=_play).start()

    def on_open_file(self, sender):
        path = sender.file_path
        subprocess.call(["open", path])

    def on_activate_project(self, sender):
        name = sender.project_name
        self.pm.set_project(name)
        self.update_projects_structure()

    def on_file_click(self, sender):
        data = sender.file_data
        
        image_path = os.path.join(data['folder'], f"{data['id']}.png")
        if os.path.exists(image_path):
            subprocess.call(["open", image_path])
            display_msg = f"🖼️ IMAGEN ABIERTA\n\n{data['full_text']}"
        else:
            display_msg = data['full_text']

        audio_path = data['audio']
        if not os.path.exists(audio_path): return

        try:
            full_audio, fs = sf.read(audio_path)
        except: return

        current_frame = 0
        playing_now = False
        start_time_real = 0
        total_frames = len(full_audio)

        while True:
            if playing_now: btn_action = "⏸️ Pausar"
            else:
                if current_frame > 0 and current_frame < total_frames: btn_action = "⏯️ Continuar"
                else: btn_action = "▶️ Reproducir"

            response = rumps.alert(
                title=f"Archivo {data['id']}",
                message=display_msg,
                ok="Cerrar",
                cancel="⏮️ Reiniciar",
                other=btn_action
            )

            if response == 1: 
                sd.stop()
                break 
            elif response == 0:
                sd.stop()
                current_frame = 0
                playing_now = False
            else: 
                if playing_now:
                    sd.stop()
                    elapsed_time = time.time() - start_time_real
                    frames_played = int(elapsed_time * fs)
                    current_frame += frames_played
                    if current_frame > total_frames: current_frame = total_frames
                    playing_now = False
                else:
                    if current_frame >= total_frames: current_frame = 0
                    remaining_audio = full_audio[current_frame:]
                    if len(remaining_audio) > 0:
                        sd.play(remaining_audio, fs)
                        start_time_real = time.time()
                        playing_now = True
                    else:
                        playing_now = False

    def on_create_project(self, _):
        window = rumps.Window(title="Nuevo Proyecto", message="Nombre:", dimensions=(200, 20))
        response = window.run()
        if response.clicked and response.text.strip():
            safe_name = response.text.strip().replace("/", "-")
            self.pm.set_project(safe_name)
            self.update_projects_structure()

    @rumps.clicked("📂 Abrir Carpeta en Finder")
    def open_finder(self, _):
        path = os.path.join(self.pm.base_dir, self.pm.current_project)
        subprocess.call(["open", path])

    def load_models(self):
        try:
            if getattr(sys, 'frozen', False): base_path = sys._MEIPASS
            else: base_path = os.path.dirname(os.path.abspath(__file__))
            model_path = os.path.join(base_path, "kokoro-v1.0.onnx")
            voices_path = os.path.join(base_path, "voices-v1.0.bin")
            self.g2p_es = EspeakG2P(language="es")
            self.g2p_en = EspeakG2P(language="en-us")
            self.kokoro = Kokoro(model_path, voices_path)
            self.is_loading = False
            if "Cargando modelos..." in self.menu:
                self.menu["Cargando modelos..."].title = "Estado: Listo 🟢"
            self.set_state(ICON_IDLE)
        except Exception as e:
            self.set_state(ICON_ERROR)
            rumps.alert(f"Error fatal:\n{e}")

    def set_state(self, state): self.title = state

    def on_press(self, key): self.keys_pressed.add(key); self.check_hotkeys()
    def on_release(self, key): 
        if key in self.keys_pressed: self.keys_pressed.remove(key)

    def check_hotkeys(self):
        if not any(k in self.keys_pressed for k in [keyboard.Key.cmd, keyboard.Key.cmd_l, keyboard.Key.cmd_r]): return
        has_alt = any(k in self.keys_pressed for k in [keyboard.Key.alt, keyboard.Key.alt_l, keyboard.Key.alt_r])
        has_ctrl = any(k in self.keys_pressed for k in [keyboard.Key.ctrl, keyboard.Key.ctrl_l, keyboard.Key.ctrl_r])

        for k in self.keys_pressed:
            if hasattr(k, 'char') and k.char:
                c = k.char
                if has_alt:
                    if c in ['s', 'S']: self.keys_pressed.clear(); self.action_selection(False); return
                    if c in ['a', 'A']: self.keys_pressed.clear(); self.action_capture(); return
                    if c in ['q', 'Q']: self.keys_pressed.clear(); self.stop_audio(None); return
                if has_ctrl and c in ['t', 'T']:
                    self.keys_pressed.clear(); self.action_selection(True, 'en', 'es'); return

    @rumps.clicked("📷 Capturar Pantalla (Cmd+Alt+A)")
    def menu_capture(self, _): self.action_capture()
    
    @rumps.clicked("🖼️ Procesar Batch de Imágenes...")
    def menu_batch_images(self, _):
        if self.is_loading: return
        files = self.select_files_mac(mode="images")
        if not files: return
        threading.Thread(target=self.run_batch_process, args=(files, False)).start()

    @rumps.clicked("🖼️🌪️ Batch + Fusionar Automático...")
    def menu_batch_and_merge(self, _):
        if self.is_loading: return
        files = self.select_files_mac(mode="images")
        if not files: return
        threading.Thread(target=self.run_batch_process, args=(files, True)).start()

    @rumps.clicked("📄🌪️ PDF a Audio (Batch + Merge)...")
    def menu_pdf_batch(self, _):
        if self.is_loading: return
        pdf_list = self.select_files_mac(mode="pdf")
        if not pdf_list: return
        pdf_path = pdf_list[0] 

        def _process_pdf_thread():
            self.set_state(ICON_PDF)
            print(f"📄 Convirtiendo PDF: {pdf_path}")
            try:
                with tempfile.TemporaryDirectory() as temp_dir:
                    images = convert_from_path(pdf_path, dpi=300, output_folder=temp_dir, fmt='png', output_file='page')
                    image_paths = sorted([os.path.join(temp_dir, f) for f in os.listdir(temp_dir) if f.endswith('.png')])
                    if not image_paths:
                        rumps.alert("Error", "No se pudieron extraer imágenes del PDF.")
                        self.set_state(ICON_IDLE)
                        return
                    self.run_batch_process(image_paths, auto_merge=True)
            except Exception as e:
                print(f"❌ Error PDF: {e}")
                rumps.alert("Error PDF", f"Asegúrate de tener poppler instalado.\n{e}")
                self.set_state(ICON_IDLE)
        threading.Thread(target=_process_pdf_thread).start()

    # --- NUEVA FUNCIÓN PARA EPUB (Usa PyMuPDF) ---
    @rumps.clicked("📚🌪️ EPUB a Audio (Batch + Merge)...")
    def menu_epub_batch(self, _):
        if self.is_loading: return
        epub_list = self.select_files_mac(mode="epub")
        if not epub_list: return
        epub_path = epub_list[0] 

        def _process_epub_thread():
            self.set_state(ICON_EPUB)
            print(f"📚 Procesando EPUB: {epub_path}")
            try:
                # Abrir documento con PyMuPDF (Soporta EPUB, MOBI, etc)
                doc = fitz.open(epub_path)
                
                with tempfile.TemporaryDirectory() as temp_dir:
                    image_paths = []
                    
                    # Iterar por cada página del libro
                    for page_num, page in enumerate(doc):
                        # Renderizar página a imagen (Zoom=2 para mejor calidad OCR)
                        mat = fitz.Matrix(2, 2) 
                        pix = page.get_pixmap(matrix=mat)
                        
                        img_filename = f"page_{page_num:04d}.png"
                        full_path = os.path.join(temp_dir, img_filename)
                        pix.save(full_path)
                        image_paths.append(full_path)
                        
                        # Feedback visual ligero en consola
                        if page_num % 10 == 0: print(f"📚 Renderizando pág {page_num}...")

                    print(f"📚 Se generaron {len(image_paths)} páginas. Enviando a OCR...")
                    self.run_batch_process(image_paths, auto_merge=True)
                    
            except Exception as e:
                print(f"❌ Error EPUB: {e}")
                rumps.alert("Error EPUB", f"No se pudo leer el ebook.\n{e}")
                self.set_state(ICON_IDLE)

        threading.Thread(target=_process_epub_thread).start()


    @rumps.clicked("📝 Leer Selección (Cmd+Alt+S)")
    def menu_selection(self, _): self.action_selection(False)
    @rumps.clicked("🇬🇧 Traducir Selección EN -> ES (Cmd+Ctrl+T)")
    def menu_translate_en_es(self, _): self.action_selection(True, 'en', 'es')
    @rumps.clicked("🇪🇸 Traducir Selección ES -> EN")
    def menu_translate_es_en(self, _): self.action_selection(True, 'es', 'en')
    @rumps.clicked("⛔ Detener Audio (Cmd+Alt+Q)")
    def stop_audio(self, _): sd.stop(); self.is_playing = False; self.set_state(ICON_IDLE)

    def action_capture(self):
        if self.is_loading: return
        threading.Thread(target=self.run_ocr_process).start()

    def action_selection(self, translate, source='auto', target='es'):
        if self.is_loading: return
        threading.Thread(target=self.run_clipboard_process, args=(translate, source, target)).start()

    def run_ocr_process(self):
        self.set_state(ICON_THINKING)
        temp_img = "/tmp/ocr_capture.png"
        if os.path.exists(temp_img): os.remove(temp_img)
        try:
            subprocess.run(["screencapture", "-i", "-x", "-r", temp_img], check=True)
            full_text = " ".join([i[0] for i in ocrmac.OCR(temp_img).recognize()])
            if full_text.strip(): self._process_and_speak(full_text, "es", temp_img, play_audio=True)
            else: self.set_state(ICON_IDLE)
        except: self.set_state(ICON_IDLE)

    def run_batch_process(self, file_paths, auto_merge=False):
        self.set_state(ICON_BATCH)
        total = len(file_paths)
        print(f"📦 Iniciando batch de {total} imágenes (Auto-Merge: {auto_merge})...")
        
        processed_count = 0
        
        for idx, img_path in enumerate(file_paths):
            if not os.path.exists(img_path): continue
            
            self.title = f"{ICON_BATCH} {idx+1}/{total}"
            
            try:
                full_text = " ".join([i[0] for i in ocrmac.OCR(img_path).recognize()])
                
                if full_text.strip():
                    self._process_and_speak(full_text, "es", img_path, play_audio=False)
                    processed_count += 1
                
                time.sleep(0.5)
                
            except Exception as e:
                print(f"Error en {img_path}: {e}")

        if auto_merge and processed_count > 0:
            self.set_state(ICON_MERGING)
            print("🌪️ Ejecutando fusión automática...")
            folder_name = self.pm.create_merge()
            
            self.set_state(ICON_IDLE)
            msg = f"Batch y Fusión Completados.\nCarpeta creada: {folder_name}"
        else:
            self.set_state(ICON_IDLE)
            msg = f"Se procesaron {processed_count} imágenes."

        rumps.notification("Kokoro Reader", "Proceso Terminado", msg)
        rumps.timer(0.1)(lambda _: self.update_projects_structure())

    def run_clipboard_process(self, translate, source, target):
        self.set_state(ICON_THINKING)
        try:
            subprocess.run("""osascript -e 'tell application "System Events" to keystroke "c" using {command down}'""", shell=True, check=True)
            time.sleep(0.3)
            text = subprocess.check_output("pbpaste", env={'LANG': 'en_US.UTF-8'}).decode('utf-8')
            if not text.strip(): self.set_state(ICON_IDLE); return

            if translate:
                if len(text)>4500: text=text[:4500]
                text = GoogleTranslator(source=source, target=target).translate(text)
                lang = target
            else: lang = "es"
            self._process_and_speak(text, lang, play_audio=True)
        except: self.set_state(ICON_IDLE)

    def normalize_text_for_tts(self, text):
        import re
        
        # 1. Unir líneas partidas (Hyphenation fix)
        # Ejemplo: "con- testar" -> "contestar"
        text = re.sub(r'(\w)-\s*\n\s*(\w)', r'\1\2', text)
        
        # 2. Unir líneas que NO terminan en puntuación
        # Si una línea termina en letra y la siguiente empieza en minúscula, es la misma frase.
        # Reemplazamos el salto de línea por un espacio.
        lines = text.split('\n')
        new_lines = []
        for i in range(len(lines) - 1):
            line = lines[i].strip()
            next_line = lines[i+1].strip()
            
            if not line: # Línea vacía
                new_lines.append(line)
                continue
                
            # Si la línea no acaba en .,;:!? y la siguiente empieza con minúscula o letra
            if line and line[-1] not in ".!?;:" and next_line and next_line[0].islower():
                new_lines.append(line + " ") # Añadimos espacio, no salto
            else:
                new_lines.append(line + "\n") # Mantenemos el salto original o párrafo
                
        new_lines.append(lines[-1]) # Añadir la última
        text = "".join(new_lines)
        
        # 3. Limpieza final de espacios
        text = re.sub(r'\s+', ' ', text).strip()
        
        # ... resto de tu código de puntuación ...
        text = text.replace("...", ".") # Tu truco anterior
        return text
    
    def apply_radio_filter(self, audio, sr):
        """
        Aplica un filtro suave para eliminar el siseo digital y dar cuerpo.
        """
        # 1. Filtro Paso Bajo (Low-pass) a 7500Hz: Elimina el "metal" agudo
        sos = signal.butter(6, 7500, 'low', fs=sr, output='sos')
        filtered = signal.sosfilt(sos, audio)
        
        # 2. Normalización de volumen (para que no suene bajito)
        max_val = np.max(np.abs(filtered))
        if max_val > 0:
            filtered = filtered / max_val * 0.95 # Normalizar al 95%
            
        return filtered

    def _process_and_speak(self, text, lang="es", image_source=None, play_audio=True):
        try:
            if self.is_playing: sd.stop()
            
            # --- Limpieza del texto ---
            if lang == "es":
                text = self.normalize_text_for_tts(text)
            
            if len(text) > 6000: text = text[:6000]
            
            # --- SELECCIÓN DE VOZ CORREGIDA ---
            if lang == "es":
                # Intentamos hacer la mezcla de voces CORRECTAMENTE
                try:
                    # Obtenemos los vectores (números) reales de las voces
                    style_santa = self.kokoro.get_voice_style('em_santa')
                    style_alex = self.kokoro.get_voice_style('em_alex')
                    
                    # Realizamos la mezcla matemática: 70% Santa, 30% Alex
                    # Nota: Esto crea una nueva voz personalizada al vuelo
                    voice = (style_santa * 0.7) + (style_alex * 0.3)
                    
                    print("🗣️ Usando mezcla de voces: 70% Santa + 30% Alex")
                except Exception as e:
                    # Si falla la mezcla (o no encuentra las voces), usamos una por defecto segura
                    print(f"⚠️ Falló la mezcla, usando ef_dora por defecto. Error: {e}")
                    voice = "ef_dora" 

                base_speed = 0.85
                
                if len(text) < 50: # Es un título o frase corta
                    final_speed = base_speed - 0.1 # Más lento (0.75) para énfasis
                elif len(text) > 200: # Párrafo denso
                    final_speed = base_speed + 0.1 # Un poco más fluido (0.95)
                else:
                    final_speed = base_speed

                print(f"⚡ Velocidad ajustada: {final_speed} para texto de {len(text)} caracteres")
            else:
                voice = "af_bella" # Voz inglés
                final_speed = 0.9

            phonemes, _ = self.g2p_es(text) if lang=="es" else self.g2p_en(text)
            
            if not phonemes: return

            # Generación
            samples, sr = self.kokoro.create(
                phonemes, 
                voice=voice, 
                speed=final_speed, 
                trim=True, 
                is_phonemes=True
            )
            
            if play_audio: self.set_state(ICON_SAVING)

            samples = self.apply_radio_filter(samples, sr)
            
            # Guardado
            self.pm.save_entry(text, samples, sr, image_source)
            
            if play_audio:
                rumps.timer(0.1)(lambda _: self.update_projects_structure())
                self.set_state(ICON_SPEAKING)
                self.is_playing = True
                
                # Reproducción
                sd.play(samples, sr)
                sd.wait() 
                
                self.is_playing = False
                self.set_state(ICON_IDLE)
                
        except Exception as e:
            print(f"❌ Error en TTS: {e}")
            if play_audio:
                self.set_state(ICON_ERROR)
                time.sleep(2)
                self.set_state(ICON_IDLE)

if __name__ == "__main__":
    KokoroBarApp().run()