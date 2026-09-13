extends SceneTree

func _init() -> void:
	call_deferred("evaluate")

func evaluate() -> void:
	for build: String in ["steam","ice_fire"]:
		var run: RunController = RunController.new()
		run.new_run(42)
		var steps: int = 0
		while run.state.phase not in ["won","lost"] and steps < 20000:
			if run.state.phase == "recipe":
				var preference: Array = ["pressure","burst","wide","recycle","caramel","reheat","crust"] if build == "steam" else ["ice","cold_spice","long","burn","caramel","reheat","crust"]
				var chosen: String = ""
				for id: String in preference:
					if id in run.state.choices: chosen = id; break
				if chosen.is_empty() and not run.state.choices.is_empty(): chosen = run.state.choices[0]
				if chosen.is_empty(): run.skip_recipe()
				else: run.choose_recipe(chosen)
			if run.state.phase == "prepare":
				var wants: Array = ["bun","toast","pudding","popcorn","garlic"] if build == "steam" else ["bun","toast","pudding","tea","pepper","garlic"]
				for refresh: int in range(3):
					for i: int in range(run.state.offers.size()):
						if run.state.offers[i].id in wants: run.shop.buy(i)
					if run.state.coins >= 6: run.shop.refresh()
				if run.state.units.any(func(u: Dictionary) -> bool: return u.hp < run.board.max_hp(u.id)*0.6): run.board.repair()
				run.start()
			# Uses only normal placement costs and cooldowns. Prioritizes marked lanes.
			var rows: Array = [1,2,3] if run.state.wave == 1 else [0,1,2,3,4]
			var plan: Array = []
			for row: int in rows: plan.append(["bun",row,1])
			for row: int in [1,2,3]: plan.append(["pudding",row,0])
			for row: int in rows: plan.append(["toast",row,6])
			for row: int in rows:
				plan.append(["popcorn" if build == "steam" else "tea",row,2])
				plan.append(["bun" if build == "steam" else "pepper",row,4])
				plan.append(["garlic",row,3])
			for row: int in rows: plan.append(["bun",row,5])
			for entry: Array in plan:
				if run.state.cards.has(entry[0]) and run.board.at(entry[1],entry[2]).is_empty():
					run.board.place(entry[0],entry[1],entry[2],false)
			run.advance(0.25)
			steps += 1
		print("AUTOPLAY ",JSON.stringify({"build":build,"seed":42,"phase":run.state.phase,"wave":run.state.wave,"seconds":run.state.elapsed,"pantry":run.state.pantry,"metrics":run.state.metrics,"cards":run.state.cards,"recipes":run.state.recipes}))
	quit()
