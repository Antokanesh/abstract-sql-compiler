import { AbstractSqlQuery } from '../../src/AbstractSQLCompiler';

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

describe('Count', () => {
	test(['SelectQuery', ['Select', [['Count', '*']]]], (result, sqlEquals) => {
		it('should produce a valid COUNT(*) statement', () => {
			sqlEquals(result.query, 'SELECT COUNT(*)');
		});
	});
});
