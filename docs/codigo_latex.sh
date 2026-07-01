#!/bin/bash

# Función que procesa un fichero específico
compilar_fichero() {
    FICHERO="$1"
    
    # Comprobar si el archivo realmente existe
    if [ ! -f "$FICHERO" ]; then return; fi

    # Extraer el número del tema (ej: de "tema3-algo.md" extrae "3")
    NUM_TEMA=$(echo "$FICHERO" | sed -E 's/^tema([0-9]+)-.*/\1/')
    
    # Formatear a dos dígitos (ej: "3" se convierte en "02" o "12" se queda "12")
    NUM_FORMATEADO=$(printf "%02d" "$NUM_TEMA")
    
    # Definir y crear la carpeta de destino específica para este tema
    CARPETA_DESTINO="imagenes/tema$NUM_FORMATEADO"
    mkdir -p "$CARPETA_DESTINO"

    echo "🔄 Procesando archivo $FICHERO en busca de moléculas y esquemas..."

    # Buscar todas las líneas que abren un bloque chemfig
    grep -n '^##latex' "$FICHERO" | while read -r linea; do
        num_linea=$(echo "$linea" | cut -d: -f1)
        contenido_linea=$(echo "$linea" | cut -d: -f2-)

        # Extraer el ID y el atom sep
        ID=$(echo "$contenido_linea" | grep -o 'id=[a-zA-Z0-9_-]*' | sed 's/id=//g')
        TAMANO=$(echo "$contenido_linea" | grep -o 'sep=[a-zA-Z0-9.]*' | sed 's/sep=//g')

        if [ -z "$ID" ]; then ID="molecula_$num_linea"; fi
        if [ -z "$TAMANO" ]; then TAMANO="3em"; fi

        # EXTRAER CÓDIGO (Corregido para detenerse en el cierre de comentario de HTML '-->')
        CODIGO_MOLECULA=$(tail -n +$((num_linea+1)) "$FICHERO" | tr -d '\r' | sed -n '1,/^-->/p' | grep -v '^-->' | grep -v '^#|' | tr '\n' ' ' | sed 's/  */ /g;s/^ //;s/ $//')

        if [ ! -z "$CODIGO_MOLECULA" ]; then
            
            CONTENIDO_FINAL="$CODIGO_MOLECULA"

            # Generar el archivo temporal de LaTeX
            cat << TEX > temp_chem_$ID.tex
\documentclass[tikz,border=2mm]{standalone}
\usepackage{chemfig}
\usepackage{ragged2e}
\usepackage[skins]{tcolorbox}
\usepackage{wrapfig}
\usepackage{longfbox}
\usepackage{array}
\usepackage{color, colortbl,xcolor}
\usepackage{tikz}
\usetikzlibrary{shapes,snakes}
\usepackage{xcolor}


% Cargar soporte para fórmulas de forma limpia
\usepackage{mhchem}
\usepackage{modiagram}

\setchemfig{atom sep=$TAMANO}
\begin{document}
$CONTENIDO_FINAL
\end{document}
TEX
            
            # Compilar
            pdflatex -interaction=nonstopmode temp_chem_$ID.tex > temp_compile.log 2>&1
            
            if [ -f temp_chem_$ID.pdf ]; then
                pdf2svg temp_chem_$ID.pdf "$CARPETA_DESTINO/$ID.svg" 2>/dev/null
                echo "✅ Generada con éxito: $CARPETA_DESTINO/$ID.svg (Tamaño: $TAMANO)"
                rm -f "$CARPETA_DESTINO/${ID}_error.log"
            else
                echo "❌ Error al compilar la molécula $ID en la línea $num_linea de $FICHERO"
                mv temp_compile.log "$CARPETA_DESTINO/${ID}_error.log"
                echo "   🔍 Log de error en: $CARPETA_DESTINO/${ID}_error.log"
            fi
        fi
    done

    # Limpieza de temporales de esta ronda
    rm -f temp_*
}

# 1. Compilación inicial de todos los ficheros que existan al arrancar
echo "🚀 Buscando y compilando archivos Markdown existentes..."
for f in tema*-*.md; do
    if [ -f "$f" ]; then
        compilar_fichero "$f"
    fi
done

# 2. Vigilancia continua del directorio
echo "👀 Vigilando cambios en archivos tema*-*.md..."
inotifywait -m -e close_write --format '%f' . | while read -r FICHERO_MODIFICADO; do
    # Filtrar para que solo actúe si el archivo modificado sigue el patrón correcto
    if [[ "$FICHERO_MODIFICADO" =~ ^tema[0-9]+-.*\.md$ ]]; then
        compilar_fichero "$FICHERO_MODIFICADO"
    fi
done