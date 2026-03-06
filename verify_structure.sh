#!/bin/bash
echo "📁 Estructura del Proyecto ReaderPro"
echo "===================================="
echo ""
echo "📦 Domain Layer:"
ls -d ReaderPro/Domain/*/ 2>/dev/null | sed 's|ReaderPro/Domain/||' | sed 's|/$||' | sed 's/^/  - /'
echo ""
echo "📦 Application Layer:"
ls -d ReaderPro/Application/*/ 2>/dev/null | sed 's|ReaderPro/Application/||' | sed 's|/$||' | sed 's/^/  - /'
echo ""
echo "📦 Infrastructure Layer:"
ls -d ReaderPro/Infrastructure/Adapters/*/ 2>/dev/null | sed 's|ReaderPro/Infrastructure/Adapters/||' | sed 's|/$||' | sed 's/^/  - /'
echo ""
echo "📦 UI Layer:"
ls -d ReaderPro/UI/*/ 2>/dev/null | sed 's|ReaderPro/UI/||' | sed 's|/$||' | sed 's/^/  - /'
echo ""
echo "📦 Tests:"
ls -d ReaderPro/Tests/*/ 2>/dev/null | sed 's|ReaderPro/Tests/||' | sed 's|/$||' | sed 's/^/  - /'
echo ""
echo "✅ Archivos Swift creados:"
fd -e swift . ReaderPro 2>/dev/null | sed 's|ReaderPro/||' | sed 's/^/  ✓ /'
