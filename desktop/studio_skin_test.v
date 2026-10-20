module main

fn test_a_skin_with_no_pictures_is_just_its_name() {
	skin := StudioSkin{
		id: 'plain'
		name: 'Plain'
	}
	assert skin.cfg() == 'name=Plain\n'
}

fn test_a_picture_becomes_a_bitmap_with_a_size() {
	mut skin := StudioSkin{
		id: 'mine'
	}
	skin.widgets[0] = StudioWidget{
		file: 'close.png'
		art: 12
	}
	cfg := skin.cfg()
	assert cfg.contains('name=mine\n')
	assert cfg.contains('widget.close=bitmap:close.png\n')
	assert cfg.contains('widget.close.size=12\n')
	assert !cfg.contains('plate')
}

fn test_a_plate_doubles_the_control_around_the_picture() {
	mut skin := StudioSkin{
		id: 'mine'
		plate: .grey
	}
	skin.widgets[2] = StudioWidget{
		file: 'maximize.png'
		art: 10
	}
	cfg := skin.cfg()
	assert cfg.contains('widget.maximize.plate=bevel:#c0c0c0:#ffffff:#808080:#000000\n')
	assert cfg.contains('widget.maximize.size=20\n')
}

fn test_what_the_studio_writes_the_desktop_reads_without_complaint() {
	mut skin := StudioSkin{
		id: 'mine'
		name: 'My skin'
		plate: .shaded
	}
	for index in 0 .. 5 {
		skin.widgets[index] = StudioWidget{
			file: studio_widget_file(index)
			art: 11
		}
	}
	parsed := parse_skin('mine', '', skin.cfg())
	assert parsed.problems.len == 0
	assert parsed.name == 'My skin'
	close := parsed.widgets['close'] or { panic('no close') }
	assert close.normal.kind == .bitmap
	assert close.plate.kind == .bevel
	assert close.size == 22
}

fn test_a_skin_reads_back_into_the_editor() {
	mut skin := StudioSkin{
		id: 'mine'
		name: 'My skin'
		plate: .grey
	}
	skin.widgets[1] = StudioWidget{
		file: 'minimize.png'
		art: 9
	}
	back := studio_skin_from_cfg('mine', skin.cfg())
	assert back.name == 'My skin'
	assert back.plate == .grey
	assert back.widgets[1].file == 'minimize.png'
	assert back.widgets[1].art == 9
	assert back.widgets[0].file == ''
}

fn test_control_sizes_stay_within_what_a_skin_may_ask() {
	assert studio_control_size(2, .none_) == 6
	assert studio_control_size(60, .grey) == 64
	assert studio_control_size(16, .none_) == 16
}
