module misc;

import sqlited;
import utils;

struct_type[] deserialize(alias struct_type)(Row r) {
	struct_type[1] instance;
	foreach (i, member; __traits(derivedMembers, struct_type)) {
		alias type = typeof(__traits(getMember, member, instance[0]));
		static if (!is(type == function)) {
			__traits(getMember, member, instance[0]) = r.getAs!(type)(i);
		}
	}
	return instance;
}

struct_type[] deserialize(alias struct_type)(Row[] ra) {
	struct_type[] result;
	foreach (r; ra) {
		result ~= deserialize(r);
	}
	return result;
}

/// usage : table.select("name","surname").where!("age","sex", (age, sex) => sex.as!Sex == Sex.female, age.as!uint < 40))
/// or table.select("name").where!((type) => type.as!string == "table")("type").as!string;
/// or join().select()
/+
auto where(S,T...)(S selectResult, T )

auto where(S,T...)(S selectResult) {
	foreach(i,Element;T) {
		static if (i == 0) {
			static assert(is(Element == delegeate) || is(Element == function),
				"first template argument to where has to be a delegate or a function");
			static assert()
		}
	}
}

auto SQL(SQLElements...)(Database db) {
//	static assert (allStatiesfy(isSQLElement!SQLElements))
	foreach(elem;SQLElements) {
		static if (isSelect!elem) {
			//assert that there is just one select
		} else static if (isWhere!elem) {
			
		}
	}
}
+/
/// handlePage is used to itterate over interiorPages transparently
void* handlePageF(Database.BTreePage page,
		Database.PageRange pages,
		void* function(Database.BTreePage, Database.PageRange, void*) pageHandlerF,
		void* initialState = null) { 
		handlePage!(
			(page, pages) => initialState = pageHandlerF(page, pages, initialState)
		)(page, pages);

		return initialState;
}

template pageHandlerTypeP(alias pageHandler) {
	alias pageHandlerTypeP = typeof((cast(const)Database.BTreePage.init));
}

template pageHandlerTypePP(alias pageHandler) {
	alias pageHandlerTypePP = typeof(pageHandler(cast(const)Database.BTreePage.init, cast(const)Database.PageRange.init));
}

template handlerRetrunType(alias pageHandler) {
	alias typePP = pageHandlerTypePP!pageHandler;
	alias typeP = pageHandlerTypeP!pageHandler;

	static if (is(typePP)) {
		alias handlerRetrunType = typePP;
	} else static if (is(typeP)) {
		alias handlerRetrunType = typeP;
	} else {
		import std.conv;
		static assert(0, "pageHandler has to be callable with (BTreePage) or (BTreePage, PageRange)" ~ typeof(pageHandler).stringof);
	}
}
static assert (is(handlerRetrunType!((page, pages) => page)));
/// this is often faster. because the PageRange is cached
auto handlePage(alias pageHandler, RR = handlerRetrunType!(pageHandler)[])(const Database db, const uint pageNumber, RR returnRange = RR.init) {
	auto pageRange = db.pages();
	return handlePage!pageHandler(pageRange[pageNumber], pageRange, returnRange);
}

/// handlePage is used to itterate over interiorPages transparently
RR handlePage(alias pageHandler, RR = handlerRetrunType!(pageHandler)[])(const Database.BTreePage page,
		const Database.PageRange pages,  RR returnRange = RR.init) {
	alias hrt = handlerRetrunType!(pageHandler);
	alias defaultReturnRangeType = hrt[];

	enum nullReturnHandler = is(hrt == void) || is(hrt == typeof(null));
	pragma(msg, nullReturnHandler);
	if (returnRange is RR.init && RR.init == null && !nullReturnHandler) {

	}

	switch (page.pageType) with (Database.BTreePage.BTreePageType) {

	case tableLeafPage: {
			static if (is(typeof(pageHandler(page, pages)))) {
				static if (nullReturnHandler) {
					pageHandler(page, pages);
					break;
				} else {
					static if (is (RR == defaultReturnRangeType)) {
						return [pageHandler(page, pages)];
					} else {
						return pageHandler(page, pages);
					}

				}
			} else static if (is(typeof(pageHandler(page)))) {
				static if (nullReturnHandler) {
					pageHandler(page);
					break;
				} else {
					static if (is (RR == defaultReturnRangeType)) {
						return [pageHandler(page, pages)];
					} else {
						return pageHandler(page, pages);
					}
				}
			} else {
				import std.conv;
				static assert(0, "pageHandler has to be callable with (BTreePage) or (BTreePage, pagesRange)" ~ typeof(pageHandler).stringof);
			}
		}
		case tableInteriorPage: {
			auto cpa = page.getCellPointerArray();


			foreach(cp;cpa) {
				static if (nullReturnHandler) {
					handlePage!pageHandler(pages[BigEndian!uint(page.page[cp .. cp + uint.sizeof]) - 1], pages);
				} else {
					returnRange ~= handlePage!pageHandler(pages[BigEndian!uint(page.page[cp .. cp + uint.sizeof]) - 1], pages, returnRange);
				}
			}

			static if (nullReturnHandler) {
				handlePage!pageHandler(pages[page.header._rightmostPointer - 1], pages);
			} else {
				returnRange ~= handlePage!pageHandler(pages[page.header._rightmostPointer - 1], pages, returnRange);
			}

			break;
		}

	default:
		import std.conv;

		assert(0, "pageType not supported" ~ to!string(page.pageType));
	}

	return returnRange;

}
