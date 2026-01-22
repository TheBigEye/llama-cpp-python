#!/bin/bash

set -e

if [ "$#" -lt 2 ]; then
  echo "Usage: $0 <releases.json> <output_dir>"
  exit 1
fi

RELEASES_FILE="$1"
OUTPUT_DIR="$2"

if [ ! -f "$RELEASES_FILE" ]; then
  echo "Error: Releases file not found: $RELEASES_FILE"
  exit 1
fi

mkdir -p "$OUTPUT_DIR"

normalize_name() {
  echo "$1" | tr '[:upper:]' '[:lower:]' | sed 's/[-_.]\+/-/g'
}

packages=$(jq -r '[.[] | .assets[] | .name | select(endswith(".whl"))] | unique | .[]' "$RELEASES_FILE" | sed 's/-[0-9].*//' | sort -u)

cat > "$OUTPUT_DIR/index.html" << 'EOF'
<!DOCTYPE html>
<html>
<head>
  <meta charset="utf-8">
  <title>Simple Index</title>
</head>
<body>
<h1>Simple Index</h1>
EOF

# Para cada paquete único
for package in $packages; do
  normalized=$(normalize_name "$package")
  
  echo "  <a href=\"$normalized/\">$normalized</a><br>" >> "$OUTPUT_DIR/index.html"
  
  mkdir -p "$OUTPUT_DIR/$normalized"
  
  cat > "$OUTPUT_DIR/$normalized/index.html" << EOF
<!DOCTYPE html>
<html>
<head>
  <meta charset="utf-8">
  <title>Links for $normalized</title>
</head>
<body>
<h1>Links for $normalized</h1>
EOF
  
  jq -r --arg pkg "$package" '.[] | .assets[] | select(.name | startswith($pkg) and endswith(".whl")) | "<a href=\"\(.browser_download_url)\">\(.name)</a><br>"' "$RELEASES_FILE" >> "$OUTPUT_DIR/$normalized/index.html"
  
  cat >> "$OUTPUT_DIR/$normalized/index.html" << 'EOF'
</body>
</html>
EOF
done

cat >> "$OUTPUT_DIR/index.html" << 'EOF'
</body>
</html>
EOF

for subdir in cpu cu118 cu119 cu120 cu121 cu122 cu123 cu124; do
  mkdir -p "$OUTPUT_DIR/$subdir"
  
  cat > "$OUTPUT_DIR/$subdir/index.html" << 'EOF'
<!DOCTYPE html>
<html>
<head>
  <meta charset="utf-8">
  <title>Simple Index</title>
</head>
<body>
<h1>Simple Index</h1>
EOF
  
  for package in $packages; do
    normalized=$(normalize_name "$package")
    echo "  <a href=\"$normalized/\">$normalized</a><br>" >> "$OUTPUT_DIR/$subdir/index.html"
    
    mkdir -p "$OUTPUT_DIR/$subdir/$normalized"
    
    cat > "$OUTPUT_DIR/$subdir/$normalized/index.html" << EOF
<!DOCTYPE html>
<html>
<head>
  <meta charset="utf-8">
  <title>Links for $normalized</title>
</head>
<body>
<h1>Links for $normalized</h1>
EOF
    
    if [ "$subdir" = "cpu" ]; then
      pattern="cpu"
    else
      pattern="${subdir#cu}"
    fi
    
    jq -r --arg pkg "$package" --arg pattern "$pattern" '.[] | .assets[] | select(.name | startswith($pkg) and endswith(".whl") and (if $pattern == "cpu" then contains("cpu") else contains($pattern) end)) | "<a href=\"\(.browser_download_url)\">\(.name)</a><br>"' "$RELEASES_FILE" >> "$OUTPUT_DIR/$subdir/$normalized/index.html"
    
    cat >> "$OUTPUT_DIR/$subdir/$normalized/index.html" << 'EOF'
</body>
</html>
EOF
  done
  
  cat >> "$OUTPUT_DIR/$subdir/index.html" << 'EOF'
</body>
</html>
EOF
done

echo "PEP 503 index generated successfully in $OUTPUT_DIR"
