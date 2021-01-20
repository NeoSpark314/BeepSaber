extends Node2D

# Run HighscoreTableTest scene and inspect console output for error

const TEST_MAP_INFO_0 = {
	  "_songName": "TestSongName0",
	  "_songSubName": "TestSubName",
	  "_songAuthorName": "TestArtist",
	  "_levelAuthorName": "TestLevelAuthor",
	}

const TEST_MAP_INFO_1 = {
	  "_songName": "TestSongName1",
	  "_songSubName": "TestSubName",
	  "_songAuthorName": "TestArtist",
	  "_levelAuthorName": "TestLevelAuthor",
	}
	
var _test_hs : HighscoreTable = null

func _ready():
	var test_methodnames = []
	for method in get_method_list():
		var method_name = method.name
		if method_name.begins_with("testcase_"):
			test_methodnames.append(method_name)
			
	print("Running %d test case(s)" % len(test_methodnames))
	for test_methodname in test_methodnames:
		test_setup()
		print("--- BEGIN '%s' " % test_methodname)
		self.call(test_methodname)
		print("--- END '%s' " % test_methodname)
		test_teardown()
	
	# if we made it here, everything passed; program exits otherwise
	print('All %d test(s) passed!' % len(test_methodnames))

# setup method called before each test case
func test_setup():
	_test_hs = HighscoreTable.new()
	_test_hs.clear_table()
	
# setup method called after each test case
func test_teardown():
	pass
	
func testcase_simple_add():
	var DIFF_RANK = 1
	
	_test_hs.add_highscore(TEST_MAP_INFO_0,DIFF_RANK,"Player",10000)
	_test_hs.add_highscore(TEST_MAP_INFO_0,DIFF_RANK,"Player",20000)
	var records = _test_hs.get_records(TEST_MAP_INFO_0,DIFF_RANK)
	
	_assert_equal(records.size(),2)
	# highest score should be first
	_assert_equal(records[0].player_name,"Player")
	_assert_equal(records[0].score,20000)
	_assert_equal(records[1].player_name,"Player")
	_assert_equal(records[1].score,10000)
	
func testcase_max_records():
	var DIFF_RANK = 1
	var SCORES_TO_ADD = 20# HighscoreTable only keeps highest 10
	
	for i in range(SCORES_TO_ADD):
		_test_hs.add_highscore(
			TEST_MAP_INFO_0,
			DIFF_RANK,
			"Player",
			i * 100)# 0, 100, 200, etc.
	
	var records = _test_hs.get_records(TEST_MAP_INFO_0,DIFF_RANK)
	_assert_equal(records.size(),10)
	# check for highest/lowest kept records
	_assert_equal(records[0].score,1900)# highest
	_assert_equal(records[9].score,1000)# lowest
	
func testcase_tied_record():
	var DIFF_RANK = 1
	
	_test_hs.add_highscore(TEST_MAP_INFO_0,DIFF_RANK,"i_was_first",1000)
	_test_hs.add_highscore(TEST_MAP_INFO_0,DIFF_RANK,"im_lower",500)
	_test_hs.add_highscore(TEST_MAP_INFO_0,DIFF_RANK,"i_was_second",1000)
	
	var records = _test_hs.get_records(TEST_MAP_INFO_0,DIFF_RANK)
	_assert_equal(records.size(),3)
	# check for highest/lowest kept records
	_assert_equal(records[0].score,1000)
	_assert_equal(records[0].player_name,"i_was_first")
	_assert_equal(records[1].score,1000)
	_assert_equal(records[1].player_name,"i_was_second")
	
func testcase_multiple_maps():
	var DIFF_RANK = 1
	
	_test_hs.add_highscore(TEST_MAP_INFO_0,DIFF_RANK,"i_played_map0",1000)
	_test_hs.add_highscore(TEST_MAP_INFO_1,DIFF_RANK,"i_played_map1",2000)
	
	var records0 = _test_hs.get_records(TEST_MAP_INFO_0,DIFF_RANK)
	_assert_equal(records0.size(),1)
	_assert_equal(records0[0].score,1000)
	_assert_equal(records0[0].player_name,"i_played_map0")
	
	var records1 = _test_hs.get_records(TEST_MAP_INFO_1,DIFF_RANK)
	_assert_equal(records1.size(),1)
	_assert_equal(records1[0].score,2000)
	_assert_equal(records1[0].player_name,"i_played_map1")
	
func testcase_multiple_ranks():
	var DIFF_RANK_A = 1
	var DIFF_RANK_B = 3
	
	_test_hs.add_highscore(TEST_MAP_INFO_0,DIFF_RANK_A,"i_played_rankA",1000)
	_test_hs.add_highscore(TEST_MAP_INFO_0,DIFF_RANK_B,"i_played_rankB",2000)
	
	var recordsA = _test_hs.get_records(TEST_MAP_INFO_0,DIFF_RANK_A)
	_assert_equal(recordsA.size(),1)
	_assert_equal(recordsA[0].score,1000)
	_assert_equal(recordsA[0].player_name,"i_played_rankA")
	
	var recordsB = _test_hs.get_records(TEST_MAP_INFO_0,DIFF_RANK_B)
	_assert_equal(recordsB.size(),1)
	_assert_equal(recordsB[0].score,2000)
	_assert_equal(recordsB[0].player_name,"i_played_rankB")
	
func _assert_equal(actual,expect):
	if actual != expect:
		push_error("actual '%s' != expect '%s'" % [actual,expect])
		assert(false)
