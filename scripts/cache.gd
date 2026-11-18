class_name Cache
extends RefCounted

## Guarda em disco (`user://cache/`) o resultado dos passos caros da montagem do mundo, para o jogo abrir
## mais rápido da segunda vez em diante. O que está guardado vale enquanto o jogo for o mesmo: no projeto,
## enquanto nenhum script nem dado do mapa mudar; na build, enquanto o executável for o mesmo. `--sem-cache`
## desliga (nada é lido nem gravado).

const PASTA := "user://cache/"

static var _chave := ""
static var ligado := true
static var lidos := 0
static var gravados := 0


## A identidade do jogo: muda quando qualquer coisa que gera o mundo muda.
static func chave() -> String:
	if _chave != "":
		return _chave
	var partes := PackedStringArray()
	if OS.has_feature("editor"):
		_somar("res://scripts", partes)
		_somar("res://assets/vale/mapa", partes)
	else:
		var exe := OS.get_executable_path()
		for arq: String in [exe, exe.get_basename() + ".pck"]:
			if FileAccess.file_exists(arq):
				partes.append("%s:%d" % [arq.get_file(), FileAccess.get_modified_time(arq)])
	_chave = "\n".join(partes).sha256_text()
	return _chave


static func _somar(pasta: String, partes: PackedStringArray) -> void:
	var d := DirAccess.open(pasta)
	if d == null:
		return
	for sub in d.get_directories():
		_somar(pasta + "/" + sub, partes)
	for arq in d.get_files():
		if arq.ends_with(".uid") or arq.ends_with(".import"):
			continue
		partes.append("%s/%s:%d" % [pasta, arq, FileAccess.get_modified_time(pasta + "/" + arq)])


## O que foi guardado com este nome, ou null se não há, se é de outra versão do jogo ou se o arquivo falhou.
static func ler(nome: String) -> Variant:
	if not ligado:
		return null
	var f := FileAccess.open_compressed(PASTA + nome + ".bin", FileAccess.READ, FileAccess.COMPRESSION_ZSTD)
	if f == null:
		return null
	var de: Variant = f.get_var()
	if not (de is String) or de != chave():
		return null
	var dados: Variant = f.get_var()
	if dados != null:
		lidos += 1
	return dados


static func gravar(nome: String, dados: Variant) -> void:
	if not ligado:
		return
	DirAccess.make_dir_recursive_absolute(PASTA)
	var f := FileAccess.open_compressed(PASTA + nome + ".bin", FileAccess.WRITE, FileAccess.COMPRESSION_ZSTD)
	if f == null:
		return
	f.store_var(chave())
	f.store_var(dados)
	f.close()
	gravados += 1
