import feedParserTest from './parser/FeedParser.test';
import utilsTest from './utils/Utils.test';

export default function testsuite() {
  feedParserTest();
  utilsTest();
}
