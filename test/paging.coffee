expect = require('chai').expect
test = require('./test')


test '/pilot?$top=5', (result) ->
	it 'should select from pilot limited by 5', ->
		expect(result.query).to.equal '''
			SELECT "pilot".*
			FROM "pilot"
			LIMIT 5'''


test '/pilot?$skip=100', (result) ->
	it 'should select from pilot offset by 100', ->
		expect(result.query).to.equal '''
			SELECT "pilot".*
			FROM "pilot"
			OFFSET 100'''


test '/pilot?$top=5&$skip=100', (result) ->
	it 'should select from pilot limited by 5 and offset by 100', ->
		expect(result.query).to.equal '''
			SELECT "pilot".*
			FROM "pilot"
			LIMIT 5
			OFFSET 100'''