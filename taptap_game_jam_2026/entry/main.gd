extends Node


func _ready() -> void:
    # 开机先给标题屏（背景图 + 点击开始）；玩家确认后由 core/game_flow.gd 换成主菜单
    var request: Types.OpenUiRequest = Types.OpenUiRequest.new()
    request.path = Paths.UI_TITLE_SCREEN
    CoreSystem.event_bus.push_event(Events.OPEN_UI, request)