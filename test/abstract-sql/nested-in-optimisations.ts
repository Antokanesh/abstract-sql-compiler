import { AbstractSqlQuery } from '../../src/AbstractSQLCompiler';
import { stripIndent } from 'common-tags';

type TestCb = (
	result: { query: string },
	sqlEquals: (a: string, b: string) => void,
) => void;
// tslint:disable-next-line no-var-requires
const test = require('./test') as (
	query: AbstractSqlQuery,
	binds: any[][] | TestCb,
	cb?: TestCb,
) => void;

describe('Nested OR EQUALs should create a single IN statement', () => {
	test(
		[
			'SelectQuery',
			['Select', []],
			['From', ['Table', 'table']],
			[
				'Where',
				[
					'Or',
					['Equals', ['ReferencedField', 'table', 'field1'], ['Text', 'a']],
					[
						'Or',
						['Equals', ['ReferencedField', 'table', 'field1'], ['Text', 'b']],
						[
							'Or',
							['Equals', ['ReferencedField', 'table', 'field1'], ['Text', 'c']],
							['Equals', ['ReferencedField', 'table', 'field1'], ['Text', 'd']],
						],
					],
				],
			],
		],
		[['Text', 'a'], ['Text', 'b'], ['Text', 'c'], ['Text', 'd']],
		(result, sqlEquals) => {
			it('should produce a single IN statement', () => {
				sqlEquals(
					result.query,
					stripIndent`
						SELECT 1
						FROM "table"
						WHERE "table"."field1" IN ($1, $2, $3, $4)
					`,
				);
			});
		},
	);
});
