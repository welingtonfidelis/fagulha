extends SceneTree
## Abre os áudios baixados (ogg, mp3, wav) e grava cada um como WAV estéreo de 16 bits, para o
## tools/montar_sons.py (que só lê WAV simples) poder cortar e medir.
## Uso: godot --headless --path . -s tools/decodificar_sons.gd -- <pasta de entrada> <pasta de saída>

func _init() -> void:
	var args := OS.get_cmdline_user_args()
	if args.size() < 2:
		print("uso: -- <entrada> <saida>")
		quit(1)
		return
	var saida := args[1]
	DirAccess.make_dir_recursive_absolute(saida)
	var feitos := 0
	for caminho in _listar(args[0]):
		var s := _abrir(caminho)
		if s == null:
			print("FALHOU ", caminho)
			continue
		var nome := caminho.trim_prefix(args[0]).trim_prefix("/").replace("/", "__").get_basename() + ".wav"
		var seg := _gravar(s, saida.path_join(nome))
		print("%7.2f s  %s" % [seg, nome])
		feitos += 1
	print("DECODIFICADOS ", feitos)
	quit()


func _listar(pasta: String) -> Array[String]:
	var lista: Array[String] = []
	var d := DirAccess.open(pasta)
	if d == null:
		return lista
	for nome in d.get_files():
		if nome.get_extension().to_lower() in ["ogg", "mp3", "wav"]:
			lista.append(pasta.path_join(nome))
	for sub in d.get_directories():
		lista.append_array(_listar(pasta.path_join(sub)))
	lista.sort()
	return lista


func _abrir(caminho: String) -> AudioStream:
	match caminho.get_extension().to_lower():
		"ogg":
			return AudioStreamOggVorbis.load_from_file(caminho)
		"mp3":
			return AudioStreamMP3.load_from_file(caminho)
		"wav":
			return AudioStreamWAV.load_from_file(caminho)
	return null


func _gravar(s: AudioStream, destino: String) -> float:
	var taxa := int(AudioServer.get_mix_rate())
	var total := int(minf(s.get_length(), 400.0) * taxa)
	var p := s.instantiate_playback()
	p.start(0.0)
	var dados := PackedByteArray()
	dados.resize(total * 4)
	var feito := 0
	while feito < total:
		var bloco := p.mix_audio(1.0, mini(4096, total - feito))
		if bloco.is_empty():
			break
		for i in bloco.size():
			dados.encode_s16((feito + i) * 4, clampi(int(bloco[i].x * 32767.0), -32768, 32767))
			dados.encode_s16((feito + i) * 4 + 2, clampi(int(bloco[i].y * 32767.0), -32768, 32767))
		feito += bloco.size()
	dados.resize(feito * 4)
	var w := AudioStreamWAV.new()
	w.format = AudioStreamWAV.FORMAT_16_BITS
	w.stereo = true
	w.mix_rate = taxa
	w.data = dados
	w.save_to_wav(destino)
	return float(feito) / taxa
