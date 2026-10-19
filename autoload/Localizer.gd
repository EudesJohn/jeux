extends Node
## Traductions (DESIGN.md § 24).
##
## Le français est la langue source : les écrans écrivent leur texte en
## français et `Localizer` le remplace par la traduction du fichier .po
## (`assets/i18n/`). Un texte absent du .po reste en français : le jeu n'est
## jamais muet ni rempli de clés techniques.
##
## Deux façons d'être traduit :
##  1. **automatique** — tout `Label`/`Button`/`CheckButton` ajouté à l'arbre
##     est traduit dès son apparition (et retraduit au changement de langue) ;
##  2. **manuel** — `Localizer.format_tr("VIE %d / %d", [hp, max])` pour les
##     textes construits avec des nombres (le formatage doit se faire APRÈS
##     la traduction, sinon la clé ne correspond plus).

signal language_changed(locale: String)

const SUPPORTED: Array[String] = ["fr", "en", "fon"]
const SOURCE_META: StringName = &"i18n_source"
const ARGS_META: StringName = &"i18n_args"

## Contrôles dont le `text` n'est pas un libellé traduisible.
const SKIP_TYPES: Array[String] = ["OptionButton", "LineEdit", "TextEdit", "CodeEdit"]


func _ready() -> void:
	process_mode = Node.PROCESS_MODE_ALWAYS
	get_tree().node_added.connect(_on_node_added)
	apply(Settings.language, false)


## Change la langue de tout le jeu, sans redémarrage. `fr` reste la source.
func apply(locale: String, notify: bool = true) -> void:
	if locale not in SUPPORTED:
		locale = "fr"
	TranslationServer.set_locale(locale)
	_retranslate_tree(get_tree().root)
	if notify:
		language_changed.emit(locale)


func current_locale() -> String:
	return str(TranslationServer.get_locale())


## Vrai si le texte a une traduction dans la langue courante.
func has_translation(source: String) -> bool:
	return tr(source) != source


## `format_tr("VIE %d / %d", [hp, max])` : traduit PUIS formate (l'ordre
## inverse ne retrouverait jamais la clé du .po).
func format_tr(source: String, args: Array = []) -> String:
	var pattern := tr(source)
	return pattern % args if not args.is_empty() else pattern


## Écrit un texte dynamique en gardant sa clé et ses valeurs : le contrôle
## sera retraduit correctement au prochain changement de langue.
func set_text(control: Control, source: String, args: Array = []) -> void:
	control.set_meta(SOURCE_META, source)
	control.set_meta(ARGS_META, args)
	control.text = format_tr(source, args)


## Appelé par le signal `node_added` : seuls les contrôles porteurs d'un
## libellé sont traités, et de façon différée (le texte est souvent posé
## juste après `add_child`).
func _on_node_added(node: Node) -> void:
	if not (node is Control) or not ("text" in node):
		return
	if String(node.get_class()) in SKIP_TYPES:
		return
	localize_node.call_deferred(node)


## Traduit un contrôle. La version française d'origine est gardée en
## métadonnée : c'est la clé du .po, et elle sert à retraduire.
func localize_node(node: Node) -> void:
	if not is_instance_valid(node) or not (node is Control) or not ("text" in node):
		return
	var control := node as Control
	if String(control.get_class()) in SKIP_TYPES:
		return
	var current := str(control.text)
	if current.is_empty():
		return
	var source := str(control.get_meta(SOURCE_META, ""))
	if source.is_empty():
		source = current
		control.set_meta(SOURCE_META, source)
	elif current != source and current != tr(source):
		# Le code a réécrit le texte (score, état d'un bouton…) : la
		# nouvelle valeur devient la clé, l'ancienne est jetée.
		source = current
		control.set_meta(SOURCE_META, source)
	var translated := tr(source)
	if current != translated:
		control.text = translated


func _retranslate_tree(node: Node) -> void:
	if node is Control and node.has_meta(SOURCE_META) and "text" in node:
		var control := node as Control
		var source := str(control.get_meta(SOURCE_META))
		var args: Array = control.get_meta(ARGS_META, [])
		control.text = format_tr(source, args)
	for child in node.get_children():
		_retranslate_tree(child)
