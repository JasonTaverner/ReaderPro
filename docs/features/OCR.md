# OCR & Document Processing

ReaderPro uses Apple's Vision framework for text recognition and supports processing images, PDFs, EPUBs, and screen captures.

## OCR Engine

### VisionOCRAdapter

Implements `OCRPort` using `VNRecognizeTextRequest`.

**Configuration:**
- Recognition level: `.accurate`
- Language correction: enabled
- Recognition languages: `["es", "en"]` (Spanish primary, English secondary)
- Supported languages: ES, EN, FR, DE, PT, IT

### Recognition Methods

**From image data:**
```swift
func recognizeText(from imageData: ImageData) async throws -> RecognizedText
```
Creates CGImage from Data (via CGImageSource or NSImage fallback), then runs OCR.

**From PDF page:**
```swift
func recognizeText(from pdfPath: String, pageNumber: Int) async throws -> RecognizedText
```
Renders PDF page at 300 DPI to CGContext, then runs OCR.

**From all PDF pages:**
```swift
func recognizeText(from pdfPath: String) async throws -> [RecognizedText]
```

**From screen capture:**
```swift
func recognizeTextFromScreen(region: ScreenRegion?) async throws -> RecognizedText
```
Uses `SCScreenshotManager` to capture the display, optionally crops to region, then runs OCR.

### Output

```swift
struct RecognizedText: Equatable {
    let text: String
    let confidence: Double  // 0.0–1.0
}
```

## Screen Capture

### CaptureAndProcessUseCase

1. Checks/requests screen capture permission
2. Captures display via ScreenCaptureService
3. Runs OCR on captured image
4. Creates AudioEntry with extracted text + screenshot image
5. Saves to project

**Keyboard shortcut:** Cmd+Shift+S (from ProjectDetailView)

## Image Batch Processing

### ProcessImageBatchUseCase

Processes multiple images selected by the user.

**Flow:**
1. User selects images via NSOpenPanel
2. Each image is processed through OCR
3. Creates AudioEntry per image (text + image path)
4. Adds all entries to project
5. Reports progress during processing

**Supported formats:** PNG, JPEG, TIFF, BMP, GIF

## PDF Processing

### ProcessDocumentUseCase

Processes PDF or EPUB documents page by page.

**PDF flow:**
1. Parse with PDFParserAdapter (PDFKit)
2. Render each page at 300 DPI
3. OCR each rendered page image
4. Create AudioEntry per page
5. Optionally generate audio for each entry

**EPUB flow:**
1. Parse with EPUBParserAdapter
2. Extract text from HTML content
3. Create entries from extracted text

## Text Batch Processing

### ProcessTextBatchUseCase

Splits long text into multiple entries for easier audio generation.

**Flow:**
1. User pastes or imports large text
2. Text is split into chunks (by paragraph or character limit)
3. Each chunk becomes an AudioEntry
4. Optionally generates audio for each entry

## Integration Points

| Use Case | Presenter Method | View Action |
|---|---|---|
| Screen Capture | `captureScreen()` | "Capture Screen" button / Cmd+Shift+S |
| Image Import | `importImages(_:)` | "Import Images" button |
| PDF/EPUB Import | `importDocument(_:)` | "Import Document" button |
| Text Import | `processTextBatch(_:)` | "Import Text" button |

All operations show progress indicators in the UI and support cancellation.
