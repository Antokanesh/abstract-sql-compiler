expect = require('chai').expect
test = require('./test')

test '/pilot', (result) ->
	it 'should select from pilot', ->
		expect(result.query).to.equal('''
			SELECT "pilot".*
			FROM "pilot"
		''')

test '/pilot(1)', (result) ->
	it 'should select from pilot with id', ->
		expect(result.query).to.equal('''
			SELECT "pilot".*
			FROM "pilot"
			WHERE "pilot"."id" = 1
		''')

test '/pilot(1)/licence', (result) ->
	it 'should select from the licence of pilot with id', ->
		expect(result.query).to.equal('''
			SELECT "licence".*
			FROM "pilot",
				"licence"
			WHERE "pilot"."id" = 1
			AND "licence"."id" = "pilot"."licence"
		''')


test '/licence(1)/pilot', (result) ->
	it 'should select from the pilots of licence with id', ->
		expect(result.query).to.equal('''
			SELECT "pilot".*
			FROM "licence",
				"pilot"
			WHERE "licence"."id" = 1
			AND "licence"."id" = "pilot"."licence"
		''')


test '/pilot(1)/pilot__can_fly__plane/plane', (result) ->
	it 'should select from the plane of pilot with id', ->
		expect(result.query).to.equal('''
			SELECT "plane".*
			FROM "pilot",
				"pilot-can_fly-plane",
				"plane"
			WHERE "pilot"."id" = 1
			AND "plane"."id" = "pilot-can_fly-plane"."plane"
			AND "pilot"."id" = "pilot-can_fly-plane"."pilot"
		''')


test '/plane(1)/pilot__can_fly__plane/pilot', (result) ->
	it 'should select from the pilots of plane with id', ->
		expect(result.query).to.equal('''
			SELECT "pilot".*
			FROM "plane",
				"pilot-can_fly-plane",
				"pilot"
			WHERE "plane"."id" = 1
			AND "pilot"."id" = "pilot-can_fly-plane"."pilot"
			AND "plane"."id" = "pilot-can_fly-plane"."plane"
		''')

do ->
	bindings = [
		['pilot', 'id']
		['pilot', 'is_experienced']
		['pilot', 'name']
		['pilot', 'age']
		['pilot', 'favourite_colour']
		['pilot', 'licence']
	]
	test '/pilot(1)', 'PUT', bindings, (result) ->
		it 'should insert/update the pilot with id 1', ->
			expect(result[0].query).to.equal('''
				INSERT INTO "pilot" ("id", "is experienced", "name", "age", "favourite colour", "licence")
				VALUES (?, ?, ?, ?, ?, ?)
			''')
			expect(result[1].query).to.equal('''
				UPDATE "pilot"
				SET "id" = ?,
					"is experienced" = ?,
					"name" = ?,
					"age" = ?,
					"favourite colour" = ?,
					"licence" = ?
				WHERE "pilot"."id" = 1
			''')
	test '/pilot', 'POST', bindings, (result) ->
		it 'should insert/update the pilot with id 1', ->
			expect(result.query).to.equal('''
				INSERT INTO "pilot" ("id", "is experienced", "name", "age", "favourite colour", "licence")
				VALUES (?, ?, ?, ?, ?, ?)
			''')
do ->
	bindings = [
		['pilot', 'id']
		['pilot', 'is_experienced']
	]
	testFunc = (result) ->
		it 'should insert/update the pilot with id 1', ->
			expect(result[0].query).to.equal('''
				INSERT INTO "pilot" ("id", "is experienced")
				VALUES (?, ?)
			''')
			expect(result[1].query).to.equal('''
				UPDATE "pilot"
				SET "id" = ?,
					"is experienced" = ?
				WHERE "pilot"."id" = 1
			''')
	test '/pilot(1)', 'PATCH', bindings, {is_experienced:true}, testFunc
	test '/pilot(1)', 'MERGE', bindings, {is_experienced:true}, testFunc

do ->
	bindings = [
		['pilot__can_fly__plane', 'pilot']
		['pilot__can_fly__plane', 'plane']
		['pilot__can_fly__plane', 'id']
	]
	test '/pilot__can_fly__plane(1)', 'PUT', bindings, (result) ->
		it 'should insert/update the pilot-can_fly-plane with id 1', ->
			expect(result[0].query).to.equal('''
				INSERT INTO "pilot-can_fly-plane" ("pilot", "plane", "id")
				VALUES (?, ?, ?)
			''')
			expect(result[1].query).to.equal('''
				UPDATE "pilot-can_fly-plane"
				SET "pilot" = ?,
					"plane" = ?,
					"id" = ?
				WHERE "pilot-can_fly-plane"."id" = 1
			''')
	test '/pilot__can_fly__plane', 'POST', bindings, (result) ->
		it 'should insert/update the pilot-can_fly-plane with id 1', ->
			expect(result.query).to.equal('''
				INSERT INTO "pilot-can_fly-plane" ("pilot", "plane", "id")
				VALUES (?, ?, ?)
			''')
do ->
	bindings = [
		['pilot__can_fly__plane', 'pilot']
	]
	testFunc = (result) ->
		it 'should insert/update the pilot with id 1', ->
			expect(result[0].query).to.equal('''
				INSERT INTO "pilot-can_fly-plane" ("pilot")
				VALUES (?)
			''')
			expect(result[1].query).to.equal('''
				UPDATE "pilot-can_fly-plane"
				SET "pilot" = ?
				WHERE "pilot-can_fly-plane"."id" = 1
			''')
	test '/pilot__can_fly__plane(1)', 'PATCH', bindings, {pilot:1}, testFunc
	test '/pilot__can_fly__plane(1)', 'MERGE', bindings, {pilot:1}, testFunc


test '/pilot(1)/$links/licence', (result) ->
	it 'should select the list of licence ids, for generating the links', ->
		expect(result.query).to.equal('''
			SELECT "pilot"."licence"
			FROM "pilot"
			WHERE "pilot"."id" = 1
		''')


test '/pilot(1)/pilot__can_fly__plane/$links/plane', (result) ->
	it 'should select the list of plane ids, for generating the links', ->
		expect(result.query).to.equal('''
			SELECT "pilot-can_fly-plane"."plane"
			FROM "pilot",
				"pilot-can_fly-plane"
			WHERE "pilot"."id" = 1
			AND "pilot"."id" = "pilot-can_fly-plane"."pilot"
		''')


test.skip '/pilot(1)/favourite_colour/red', (result) ->
	it "should select the red component of the pilot's favourite colour"


test.skip '/method(1)/child?foo=bar', (result) ->
	it 'should do something..'
