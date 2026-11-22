class_name BichoFicha
extends Node3D
## O nó de cada bicho dos grupos feitos por código (a marmota, o pato, o corvo e o lagópode, doc §137.14): entra no
## grupo "bichos" para o scanner e o álbum acharem cada um (o nó do grupo fica na origem) e passa os sustos dos
## tiros para o grupo. `especie` é a página do álbum e a ficha do scanner.

const FICHAS := {
	"lagopode": {"nome": "Lagópode", "tipo": "bicho · bando",
		"linhas": ["Vive nas pedras e na neve do alto.", "Asa branca, dorso da cor da pedra.", "Voa baixo e pousa logo adiante."]},
	"marmota": {"nome": "Marmota", "tipo": "bicho · colônia",
		"linhas": ["Mora em tocas na campina alta.", "Uma fica de vigia em cima da pedra.", "Com o robô perto, correm para a toca."]},
	"pato": {"nome": "Pato-arlequim", "tipo": "bicho · casal",
		"linhas": ["Nada na água fria das quedas.", "Mergulha atrás de comida no fundo.", "No frio, gosta da água morna das fontes."]},
	"corvo": {"nome": "Corvo", "tipo": "bicho · casal",
		"linhas": ["Plana em volta do pico e da vila.", "Pousa nos telhados e nas pedras altas.", "Às vezes dá cambalhota no ar."]},
}

var especie := ""
var dono: Node


static func nova(qual: String, de: Node, meio := 0.3) -> BichoFicha:
	var f := BichoFicha.new()
	f.especie = qual
	f.dono = de
	f.set_meta("meio_altura", meio)
	f.add_to_group("bichos")
	return f


func assustar(ponto: Vector3) -> void:
	if is_instance_valid(dono) and dono.has_method("assustar"):
		dono.assustar(ponto)


func ficha() -> Dictionary:
	return FICHAS.get(especie, {"nome": "Desconhecido", "tipo": "sem registro", "linhas": []})
