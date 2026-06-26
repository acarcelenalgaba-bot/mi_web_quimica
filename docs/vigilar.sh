#!/bin/bash
mkdir -p imagenes

compilar_todo() {
    echo "🔄 Procesando archivo index.qmd en busca de moléculas y esquemas..."

    # Buscar todas las líneas que abren un bloque chemfig
    grep -n '^```chemfig' index.qmd | while read -r linea; do
        num_linea=$(echo "$linea" | cut -d: -f1)
        contenido_linea=$(echo "$linea" | cut -d: -f2-)

        # Extraer el ID (ej: id=mol1) y el atom sep (ej: sep=2.5em) de la misma línea
        ID=$(echo "$contenido_linea" | grep -o 'id=[a-zA-Z0-9_-]*' | sed 's/id=//g')
        TAMANO=$(echo "$contenido_linea" | grep -o 'sep=[a-zA-Z0-9.]*' | sed 's/sep=//g')

        # Valores por defecto si no se definen
        if [ -z "$ID" ]; then ID="molecula_$num_linea"; fi
        if [ -z "$TAMANO" ]; then TAMANO="3em"; fi

        # EXTRAER CÓDIGO (Ultra-robusto contra CRLF/Windows y saltos de línea extraños)
        CODIGO_MOLECULA=$(tail -n +$((num_linea+1)) index.qmd | tr -d '\r' | sed -n '1,/^```/p' | grep -v '^```' | grep -v '^#|' | tr '\n' ' ' | sed 's/  */ /g;s/^ //;s/ $//')

        if [ ! -z "$CODIGO_MOLECULA" ]; then
            
            # --- NUEVA LÓGICA DE DETECCIÓN ---
            # Si el código ya contiene \schemestart o \chemfig, lo dejamos tal cual.
            # Si no, lo envolvemos en \chemfig{} de forma automática.
            if echo "$CODIGO_MOLECULA" | grep -q -E '\\schemestart|\\chemfig'; then
                CONTENIDO_FINAL="$CODIGO_MOLECULA"
            else
                CONTENIDO_FINAL="\\chemfig{$CODIGO_MOLECULA}"
            fi
            # ---------------------------------

            # Generar el archivo temporal de LaTeX
            cat << TEX > temp_chem.tex
\documentclass[tikz,border=2mm]{standalone}
\usepackage{chemfig}
\setchemfig{atom sep=$TAMANO}
\begin{document}
$CONTENIDO_FINAL
\end{document}
TEX
            
            # Compilar guardando el registro para depuración de fallos de LaTeX
            pdflatex -interaction=nonstopmode temp_chem.tex > temp_compile.log 2>&1
            
            if [ -f temp_chem.pdf ]; then
                pdf2svg temp_chem.pdf imagenes/$ID.svg 2>/dev/null
                echo "✅ Generada con éxito: imagenes/$ID.svg (Tamaño: $TAMANO)"
                # Limpiar log de error si existía de antes
                rm -f imagenes/${ID}_error.log
            else
                echo "❌ Error al compilar la molécula $ID en la línea $num_linea"
                mv temp_compile.log imagenes/${ID}_error.log
                echo "   🔍 Log de error detallado en: imagenes/${ID}_error.log"
            fi
        fi
    done

    # Limpieza de temporales al finalizar la ronda
    rm -f temp_*
}

# Ejecutar al arrancar
compilar_todo

# Vigilar cambios en el archivo index.qmd
while inotifywait -e close_write index.qmd; do
    compilar_todo
done