# Audio Generation - Value Objects

## Text

Value Object que representa texto validado para Text-to-Speech.

### Reglas de Negocio

- ✅ **No puede estar vacío** (después de trimming)
- ✅ **No puede ser solo espacios/saltos de línea**
- ✅ **Máximo 6000 caracteres** (límite del script original)
- ✅ **Calcula número de palabras** automáticamente
- ✅ **Estima duración del audio** (~150 palabras por minuto)

### Uso

```swift
// ✅ Válido
let text = try Text("Hola mundo")
print(text.wordCount)          // 2
print(text.estimatedDuration)  // 0.8 segundos

// ❌ Inválido - Lanza DomainError.invalidText
try Text("")                   // Vacío
try Text("   ")                // Solo espacios
try Text(String(repeating: "a", count: 6001))  // Excede límite
```

### Implementación TDD

✅ Tests escritos primero (RED)
✅ Implementación después (GREEN)
⏳ Refactoring pendiente (REFACTOR)

### Tests

Archivo: `Tests/Domain/AudioGeneration/ValueObjects/TextTests.swift`

- ✅ 17 tests implementados
- ✅ Cobertura completa de reglas de negocio
- ✅ Casos edge: Unicode, números, puntuación
