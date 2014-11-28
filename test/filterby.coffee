expect = require('chai').expect
test = require('./test')
clientModel = require('./client-model.json')
_ = require('lodash')
{pilotFields, pilotCanFlyPlaneFields} = require('./fields')
pilotFields = pilotFields.join(', ')
pilotCanFlyPlaneFields = pilotCanFlyPlaneFields.join(', ')

operandToOData = (operand) ->
	if operand.odata?
		return operand.odata
	if _.isDate(operand)
		return "datetime'" + encodeURIComponent(operand.toISOString()) + "'"
	return operand

operandToBindings = (operand) ->
	if _.isDate(operand)
		return [['Date', operand]]
	return []

operandToSQL = (operand, resource = 'pilot') ->
	if operand.sql?
		return operand.sql
	if _.isNumber(operand)
		return operand
	if _.isDate(operand)
		return '?'
	if _.isString(operand)
		if operand.charAt(0) is "'"
			return decodeURIComponent(operand)
		fieldParts = operand.split('/')
		if fieldParts.length > 1
			mapping = clientModel.resourceToSQLMappings[fieldParts[fieldParts.length - 2]][fieldParts[fieldParts.length - 1]]
		else
			mapping = clientModel.resourceToSQLMappings[resource][operand]
		return '"' + mapping.join('"."') + '"'
	throw 'Unknown operand type: ' + operand

sqlOps =
	eq: ' ='
	ne: ' !='
	gt: ' >'
	ge: ' >='
	lt: ' <'
	le: ' <='
	and: '\nAND'
	or: '\nOR'
	add: ' +'
	sub: ' -'
	mul: ' *'
	div: ' /'
sqlOpBrackets =
	or: true

methodMaps =
	TOUPPER: 'UPPER'
	TOLOWER: 'LOWER'
	INDEXOF: 'STRPOS'

createExpression = (lhs, op, rhs) ->
	if lhs is 'not'
		return {
			odata: 'not ' + if op.odata? then '(' + op.odata + ')' else operandToOData(op)
			sql: 'NOT (\n\t' + operandToSQL(op) + '\n)'
		}
	if !rhs?
		return {
			odata: if lhs.odata? then '(' + lhs.odata + ')' else operandToOData(lhs)
			sql: operandToSQL(lhs)
		}
	lhsSql = operandToSQL(lhs)
	rhsSql = operandToSQL(rhs)
	bindings = [].concat(
		operandToBindings(lhs)
		operandToBindings(rhs)
	)
	sql = lhsSql + sqlOps[op] + ' ' + rhsSql
	if sqlOpBrackets[op]
		sql = '(' + sql + ')'
	return {
		odata: operandToOData(lhs) + ' ' + op + ' ' + operandToOData(rhs)
		sql
		bindings
	}
createMethodCall = (method, args...) ->
	return {
		odata: method + '(' + (operandToOData(arg) for arg in args).join(',') + ')'
		sql: (
			method = method.toUpperCase()
			switch method
				when 'SUBSTRINGOF'
					operandToSQL(args[1]) + " LIKE ('%' || " + operandToSQL(args[0]) + " || '%')"
				when 'STARTSWITH'
					operandToSQL(args[1]) + ' LIKE (' + operandToSQL(args[0]) + " || '%')"
				when 'ENDSWITH'
					operandToSQL(args[1]) + " LIKE ('%' || " + operandToSQL(args[0]) + ')'
				when 'CONCAT'
					'(' + (operandToSQL(arg) for arg in args).join(' || ') + ')'
				else
					if methodMaps.hasOwnProperty(method)
						method = methodMaps[method]
					switch method
						when 'SUBSTRING'
							args[1]++
					result = method + '(' + (operandToSQL(arg) for arg in args).join(', ') + ')'
					if method is 'STRPOS'
						result = "(#{result} + 1)"
					result
		)
	}

operandTest = (lhs, op, rhs) ->
	{odata, sql, bindings} = createExpression(lhs, op, rhs)
	test '/pilot?$filter=' + odata, 'GET', bindings, (result) ->
		it 'should select from pilot where "' + odata + '"', ->
			expect(result.query).to.equal '''
				SELECT ''' + pilotFields + '\n' + '''
				FROM "pilot"
				WHERE ''' + sql

methodTest = (args...) ->
	{odata, sql} = createMethodCall(args...)
	test '/pilot?$filter=' + odata, (result) ->
		it 'should select from pilot where "' + odata + '"', ->
			expect(result.query).to.equal '''
				SELECT ''' + pilotFields + '\n' + '''
				FROM "pilot"
				WHERE ''' + sql

operandTest(2, 'eq', 'name')
operandTest(2, 'ne', 'name')
operandTest(2, 'gt', 'name')
operandTest(2, 'ge', 'name')
operandTest(2, 'lt', 'name')
operandTest(2, 'le', 'name')

# Test each combination of operands
do ->
	operands = [
			2
			2.5
			"'bar'"
			"name"
			"pilot/name"
			new Date()
		]
	for lhs in operands
		for rhs in operands
			operandTest(lhs, 'eq', rhs)

do ->
	left = createExpression('age', 'gt', 2)
	right = createExpression('age', 'lt', 10)
	operandTest(left, 'and', right)
	operandTest(left, 'or', right)
	operandTest('is_experienced')
	operandTest('not', 'is_experienced')
	operandTest('not', left)

do ->
	mathOps = [
		'add'
		'sub'
		'mul'
		'div'
	]
	for mathOp in mathOps
		mathOp = createExpression('age', mathOp, 2)
		operandTest(mathOp, 'gt', 10)

do ->
	{odata, sql} = createExpression('pilot__can_fly__plane/id', 'eq', 10)
	test '/pilot?$filter=' + odata, (result) ->
		it 'should select from pilot where "' + odata + '"', ->
			expect(result.query).to.equal '''
				SELECT ''' + pilotFields + '\n' + '''
				FROM "pilot",
					"pilot-can_fly-plane"
				WHERE "pilot"."id" = "pilot-can_fly-plane"."pilot"
				AND ''' + sql

do ->
	{odata, sql} = createExpression('plane/id', 'eq', 10)
	test '/pilot(1)/pilot__can_fly__plane?$filter=' + odata, (result) ->
		it 'should select from pilot__can_fly__plane where "' + odata + '"', ->
			expect(result.query).to.equal '''
				SELECT ''' + pilotCanFlyPlaneFields + '\n' + '''
				FROM "pilot",
					"pilot-can_fly-plane",
					"plane"
				WHERE "pilot"."id" = 1
				AND "plane"."id" = "pilot-can_fly-plane"."plane"
				AND ''' + sql + '\n' + '''
				AND "pilot"."id" = "pilot-can_fly-plane"."pilot"'''

do ->
	{odata, sql} = createExpression('pilot__can_fly__plane/plane/id', 'eq', 10)
	test '/pilot?$filter=' + odata, (result) ->
		it 'should select from pilot where "' + odata + '"', ->
			expect(result.query).to.equal '''
				SELECT ''' + pilotFields + '\n' + '''
				FROM "pilot",
					"pilot-can_fly-plane",
					"plane"
				WHERE "pilot"."id" = "pilot-can_fly-plane"."pilot"
				AND "plane"."id" = "pilot-can_fly-plane"."plane"
				AND ''' + sql

	test '/pilot?$filter=' + odata, 'PATCH', [['pilot', 'name']], name: 'Peter', (result) ->
		it 'should update pilot where "' + odata + '"', ->
			expect(result.query).to.equal '''
				UPDATE "pilot"
				SET "name" = ?
				WHERE "pilot"."id" IN ((
					SELECT "pilot"."id"
					FROM "pilot-can_fly-plane",
						"plane",
						"pilot"
					WHERE "pilot"."id" = "pilot-can_fly-plane"."pilot"
					AND "plane"."id" = "pilot-can_fly-plane"."plane"
					AND "plane"."id" = 10
				))
				'''

	test '/pilot?$filter=' + odata, 'DELETE', (result) ->
		it 'should delete from pilot where "' + odata + '"', ->
			expect(result.query).to.equal '''
				DELETE FROM "pilot"
				WHERE "pilot"."id" IN ((
					SELECT "pilot"."id"
					FROM "pilot-can_fly-plane",
						"plane",
						"pilot"
					WHERE "pilot"."id" = "pilot-can_fly-plane"."pilot"
					AND "plane"."id" = "pilot-can_fly-plane"."plane"
					AND "plane"."id" = 10
				))
				'''

do ->
	name = 'Peter'
	{odata, sql} = createExpression('name', 'eq', "'#{name}'")
	test '/pilot?$filter=' + odata, 'POST', [['pilot', 'name']], {name}, (result) ->
		it 'should insert into pilot where "' + odata + '"', ->
			expect(result.query).to.equal '''
				INSERT INTO "pilot" ("name")
				SELECT "pilot".*
				FROM (
					SELECT CAST(? AS VARCHAR(255)) AS "name"
				) AS "pilot"
				WHERE ''' + sql

do ->
	oneEqOne = createExpression(1, 'eq', 1)
	{odata, sql} = createExpression(oneEqOne, 'or', oneEqOne)
	test '/pilot(1)/pilot__can_fly__plane?$filter=' + odata, (result) ->
		it 'should select from pilot__can_fly__plane where "' + odata + '"', ->
			expect(result.query).to.equal '''
				SELECT ''' + pilotCanFlyPlaneFields + '\n' + '''
				FROM "pilot",
					"pilot-can_fly-plane"
				WHERE "pilot"."id" = 1
				AND ''' + sql + '\n' + '''
				AND "pilot"."id" = "pilot-can_fly-plane"."pilot"'''

methodTest('substringof', "'Pete'", 'name')
methodTest('startswith', 'name', "'P'")
methodTest('endswith', 'name', "'ete'")
operandTest(createMethodCall('length', 'name'), 'eq', 4)
operandTest(createMethodCall('indexof', 'name', "'Pe'"), 'eq', 0)
operandTest(createMethodCall('replace', 'name', "'ete'", "'at'"), 'eq', "'Pat'")
operandTest(createMethodCall('substring', 'name', 1), 'eq', "'ete'")
operandTest(createMethodCall('substring', 'name', 1, 2), 'eq', "'et'")
operandTest(createMethodCall('tolower', 'name'), 'eq', "'pete'")
operandTest(createMethodCall('toupper', 'name'), 'eq', "'PETE'")

do ->
	concat = createMethodCall('concat', 'name', "'%20'")
	operandTest(concat, 'eq', "'Pete%20'")
	operandTest(createMethodCall('trim', concat), 'eq', "'Pete'")

operandTest(createMethodCall('round', 'age'), 'eq', 25)
operandTest(createMethodCall('floor', 'age'), 'eq', 25)
operandTest(createMethodCall('ceiling', 'age'), 'eq', 25)

test "/pilot?$filter=pilot__can_fly__plane/any(d:d/plane/name eq 'Concorde')", (result) ->
	it 'should select from pilot where ...', ->
		expect(result.query).to.equal '''
			SELECT ''' + pilotFields + '\n' + '''
			FROM "pilot"
			WHERE EXISTS (
				SELECT 1
				FROM "pilot-can_fly-plane",
					"plane"
				WHERE "pilot"."id" = "pilot-can_fly-plane"."pilot"
				AND "plane"."id" = "pilot-can_fly-plane"."plane"
				AND "plane"."name" = 'Concorde'
			)'''

test "/pilot?$filter=pilot__can_fly__plane/all(d:d/plane/name eq 'Concorde')", (result) ->
	it 'should select from pilot where ...', ->
		expect(result.query).to.equal '''
			SELECT ''' + pilotFields + '\n' + '''
			FROM "pilot"
			WHERE NOT (
				EXISTS (
					SELECT 1
					FROM "pilot-can_fly-plane",
						"plane"
					WHERE NOT (
						"pilot"."id" = "pilot-can_fly-plane"."pilot"
						AND "plane"."id" = "pilot-can_fly-plane"."plane"
						AND "plane"."name" = 'Concorde'
					)
				)
			)'''

# Switch operandToSQL permanently to using 'team' as the resource,
# as we are switch to using that as our base resource from here on.
operandToSQL = _.partialRight(operandToSQL, 'team')
do ->
	favouriteColour = 'purple'
	{odata, sql} = createExpression('favourite_colour', 'eq', "'#{favouriteColour}'")
	test '/team?$filter=' + odata, 'POST', [['team', 'favourite_colour']], {favourite_colour: favouriteColour}, (result) ->
		it 'should insert into team where "' + odata + '"', ->
			expect(result.query).to.equal '''
				INSERT INTO "team" ("favourite colour")
				SELECT "team".*
				FROM (
					SELECT CAST(? AS INTEGER) AS "favourite colour"
				) AS "team"
				WHERE ''' + sql
