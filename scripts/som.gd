class_name Som
extends RefCounted
## Atalhos de som para o mundo: um toque num ponto e um laço preso a um nó. Os WAV ficam em
## assets/sons/ (montados por tools/montar_sons.py a partir de gravações; créditos em CREDITOS.md).

const PASTA := "res://assets/sons/%s.wav"

static var _cache := {}
## Para os testes: quantas vezes cada toque saiu.
static var contagem := {}


static func stream(nome: String) -> AudioStream:
	if not _cache.has(nome):
		_cache[nome] = load(PASTA % nome)
	return _cache[nome]


## Uma das variações numeradas: "passo" com 6 dá passo_1 a passo_6.
static func variacao(prefixo: String, quantas: int) -> String:
	return "%s_%d" % [prefixo, randi_range(1, quantas)]


## Cópia do WAV com o laço ligado, do início ao fim.
static func laco_stream(nome: String) -> AudioStreamWAV:
	var base := stream(nome) as AudioStreamWAV
	var s := base.duplicate() as AudioStreamWAV
	s.loop_mode = AudioStreamWAV.LOOP_FORWARD
	s.loop_begin = 0
	s.loop_end = int(base.get_length() * base.mix_rate)
	return s


## Toque único num ponto do mundo, que se solta no fim. `cheio` é a distância em que ainda soa inteiro.
static func toque3d(pai: Node, nome: String, onde: Vector3, db := 0.0, cheio := 8.0, alcance := 90.0) -> AudioStreamPlayer3D:
	contagem[nome] = int(contagem.get(nome, 0)) + 1
	if pai == null or not pai.is_inside_tree() or not onde.is_finite():
		return null
	var p := AudioStreamPlayer3D.new()
	p.stream = stream(nome)
	p.volume_db = db
	p.unit_size = cheio
	p.max_distance = alcance
	p.pitch_scale = randf_range(0.94, 1.06)
	p.top_level = true
	pai.add_child(p)
	p.global_position = onde
	p.play()
	p.finished.connect(p.queue_free)
	return p


## Laço preso a um nó (anda com ele). Começa num ponto sorteado, para duas máquinas iguais não soarem coladas.
static func laco3d(pai: Node3D, nome: String, db := 0.0, cheio := 5.0, alcance := 45.0) -> AudioStreamPlayer3D:
	var p := AudioStreamPlayer3D.new()
	p.stream = laco_stream(nome)
	p.volume_db = db
	p.unit_size = cheio
	p.max_distance = alcance
	pai.add_child(p)
	p.play(randf() * p.stream.get_length())
	return p
