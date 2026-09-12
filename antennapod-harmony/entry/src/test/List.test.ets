import feedParserTest from './parser/FeedParser.test';
import utilsTest from './utils/Utils.test';
import sortAndFilterTest from './utils/SortAndFilter.test';
import inboxBaselineTest from './utils/InboxBaseline.test';

export default function testsuite() {
  feedParserTest();
  utilsTest();
  sortAndFilterTest();
  inboxBaselineTest();
}
