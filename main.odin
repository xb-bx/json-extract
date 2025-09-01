package jsonextract
import "base:intrinsics"
import "base:runtime"
import "core:encoding/json"
import "core:fmt"
import "core:mem"
import "core:reflect"
import "core:strconv"
import "core:strings"
import "core:text/scanner"
import "core:unicode/utf8"


Id :: string
Index :: int

QueryPart :: union {
	Id,
	Index,
}
QueryError :: enum {
	None,
	UnexpectedEnd,
	UnexpectedChar,
	InvalidIndex,
	ExpectedIdOrIndex,
    KeyNotFound,
    IndexOutOfBounds,
}
get_query_part :: proc(
	query: string,
) -> (
	part: QueryPart,
	consumed: int,
	rest: string,
	err: QueryError,
	errpos: int,
) {
	if len(query) == 0 do return nil, 0, "", .UnexpectedEnd, 0
	if query[0] == '[' {
		end := 0
		for c, i in query {
			if c == ']' {
				end = i
				break
			}
		}
		if end == 0 do return nil, 0, "", .UnexpectedEnd, 0
		index, ok := strconv.parse_int(query[1:end])
		if !ok do return nil, 0, "", .InvalidIndex, 1
		return Index(index), end + 1, query[end + 1:], nil, 0
	} else if query[0] == '.' {
		end := 0
		for c, i in query[1:] {
			if c == '[' || c == '.' {
				end = i + 1
				break
			}
		}
		if end == 0 do end = len(query)
		id := query[1:end]
		i := end
		return Id(id), len(id) + 1, query[end:], nil, 0
	} else {
		return nil, 0, "", .UnexpectedChar, 0
	}
}
Error :: union #shared_nil {
	QueryError,
	json.Error,
	json.Unmarshal_Error,
}
skip :: proc(parser: ^json.Parser) -> json.Error {
	using json
	switch parser.curr_token.kind {
	case .Invalid, .EOF, .Comma, .Colon, .Close_Brace, .Close_Bracket, .Open_Bracket:
		panic("shouldnt")
	case .Null, .False, .True, .Infinity, .Integer, .NaN, .Ident, .Float, .String:
		advance_token(parser)
	case .Open_Brace:
		advance_token(parser) or_return
		for parser.curr_token.kind != .Close_Brace {
			parse_object_key(parser, mem.nil_allocator()) or_return
			parse_colon(parser) or_return
			skip(parser)
			if parser.curr_token.kind == .Comma do json.advance_token(parser)
		}
		advance_token(parser)

	}
	return nil
}
extract :: proc(js: []byte, query: string, v: any) -> Error {
	parser := json.make_parser(js, json.Specification.JSON5)
	query := query
	pos := 0
	for query != "" {
		part, cons, rest, err, errpos := get_query_part(query)
		if err != nil do return err
		query = rest
		switch q in part {
		case Id:
			json.expect_token(&parser, .Open_Brace) or_return
            ok := false
			for parser.curr_token.kind != .Close_Brace {
				p := parser
				key := json.parse_object_key(&parser, context.allocator) or_return
				defer delete(key)
				json.parse_colon(&parser) or_return
				if key == q {
                    ok = true
					break
				} else {
					skip(&parser) or_return
				}
				if parser.curr_token.kind == .Comma do json.parse_comma(&parser)
			}
            if !ok do return .KeyNotFound
		case Index:
			json.expect_token(&parser, .Open_Bracket) or_return
            i := 0
			for parser.curr_token.kind != .Close_Bracket && i < q {
                skip(&parser) or_return 
                if parser.curr_token.kind == .Comma do json.parse_comma(&parser)
                else do break
                i += 1
            }
            if i != q do return .IndexOutOfBounds
		}
	}
    return json.unmarshal_any(js[parser.curr_token.offset:], v, .JSON5)
}

main :: proc() {
}
