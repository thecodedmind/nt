import os, strutils, db_sqlite, parseopt

const VERSION = "0.12"

var
    db: DbConn

proc ntcreate(group:string) =
    db.exec(sql"create table ? (name text, snippet text, language text)", group)

proc ntadd(group, name, language, snippet: string) =
    if not db.tryExec(sql"insert into ? (name, snippet, language) values (?, ?, ?)", group, name, snippet, language):
        db.exec(sql"create table ? (name text, language text, snippet text)", group)
        if not db.tryExec(sql"insert into ? (name, snippet, language) values (?, ?, ?)", group, name, snippet, language):
            echo "Failed to insert... "
            dbError(db)
    
proc ntdel(group, line: string) =
    db.exec(sql"delete from ? where name = ?", group, line)
        
proc ntget(group, line: string) =
    var q = "SELECT * FROM "&group&" WHERE name like '"&line&"'"
    for x in db.fastRows(sql(q)):
        echo x[0]&" ("&x[1]&")"
        echo x[2]
        echo "----"
        
proc ntshow(group, line: string) =
    var q = "SELECT * FROM "&group&" WHERE name = '"&line&"'"
    for x in db.fastRows(sql(q)):
        echo x[2]
        break
        
proc ntgetl(group, line: string) =
    var q = "SELECT * FROM "&group&" where language = '"&line&"'"
    for x in db.fastRows(sql(q)):
        echo x

proc ntgetc(group, line: string) =
    var q = "SELECT * FROM "&group&" where snippet like '%"&line&"%'"
    for x in db.fastRows(sql(q)):
        echo x
        
proc ntedit(group, name, key, line: string) =
    db.exec(sql"update ? set ? = ? where name = ?", group, key, line, name)
    
proc ntls(group: string) =
    var q = "SELECT * FROM "&group
    for x in db.fastRows(sql(q)):
        echo x[0]&" ("&x[1]&")"
        echo x[2]
        echo "----"
        
proc ntls() =
    var fq = "SELECT * from sqlite_master"
    for x in db.fastRows(sql(fq)):
        var q = "SELECT * FROM "&x[1]
        for t in db.fastRows(sql(q)):
            echo t[0]&" ("&t[1]&")"
            echo t[2]
            echo "----"
            
proc ntlst() =
    var fq = "SELECT * from sqlite_master"
    for x in db.fastRows(sql(fq)):
        echo x[1]
            
proc ntdrop(group: string) =
    db.exec(sql"drop table ?", group)
    
proc ntexec(line: string, catch: bool = false) =
    if catch:
        if not db.tryExec(sql(line)):
            dbError(db)
    else:
        for x in db.fastRows(sql(line)):
            echo x
                
proc spinLine() =
    var
        p = initOptParser()
        command, table, lang, code, name: string
        args = newSeq[string]()
            
    while true:
        p.next()
        case p.kind
        of cmdEnd: break
        of cmdShortOption, cmdLongOption:
            if p.key == "version" or p.key == "v":
                echo "NT "&VERSION
                return
                
            if p.val != "":
                if p.key == "table" or p.key == "t":
                    table = p.val
                if p.key == "lang" or p.key=="l":
                    lang = p.val
                if p.key == "code" or p.key == "c":
                    code = p.val
                if p.key == "name" or p.key == "n":
                    name = p.val
        of cmdArgument:
            if command == "":
                command = p.key
            else:
                args.add(p.key)
                
    if table == "":
        table = "nt"

    case command:
        of "help":
            echo "-------"
            echo "NT: Nim Text storage "&VERSION
            echo ""
            echo "Variables: table/t, lang/l, code/c, name/n"
            echo "Table is given a default if not supplied."
            echo ""
            echo "Commands:"
            echo "\tadd/insert/a/i [-t:table_name] [-n:entry_name] [-l:code_language] [-c:code_block]"
            echo "\t\t Inserts line.\n\t\t nt add -t:pystuff -n:def -c:def bork(): pass -l:python3"
            echo ""
            echo "\tedit/e [key_to_edit] new_input [-n:name_of_entry] [-n:name_of_table]"
            echo "\t\t Edits a line\n\t\t Renaming: nt edit name test -n:tsst\n\t\t\t Changing the snippet: nt edit code 'def bork(): pass' -n:test"
            echo ""
            echo "\tdel/d [-t:table_name] [-n:entry_name]"
            echo "\t\t Deletes an entry from a table.\n\t\t nt del -t:pystuff -n:def"
            echo ""
            echo "\texec/eval [...sql_code]"
            echo "\t\tRuns raw SQL code on the database."
            echo ""
            echo "\tdrop/dr [-t:table]"
            echo "\t\t Deletes an entire table."
            echo ""
            echo "\ttables"
            echo "\t\tLists tables in the database."
            echo ""
            echo "\tlist/ls [-t:table]"
            echo "\t\tLists entries in a table. If table=* then lists all entries in all tables."
            echo ""
            echo "\tget/g [-n:name] OR getc/gc [-c:code_block] OR getl/gl [-l:language] WITH [-t:table_name]"
            echo "\t\t Finds entries based on search"
            echo ""
            echo "\tshow/s [-n:name] [-t:table_name]"
            echo "\t\tOutput entry with name matching."
            
        of "exec", "eval", "sql":
            ntexec(args.join(" "), false)
        of "add", "a", "insert":
            if lang == "":
                lang = "none"
            if name == "" or code == "" or table == "":
                echo "Value(s) missing for `add`: name, code, table"
            else:
                ntadd(table, name, lang, code)
        of "edit", "e", "mod", "modify", "m":
            ntedit(table, name, args[0], args[1..args.len-1].join(" "))
        of "del", "d":
            if table == "" or name == "":
                echo "Value(s) missing for `del`: table, name"
            else:
                ntdel(table, name)
        of "drop", "dr":
            ntdrop(table)
        of "tables":
            ntlst()
        of "list", "ls":
            if table == "*":
                ntls()
            else:
                ntls(table)
        of "show", "s":
            if name == "" and args.len == 0:
                echo "Value missing: name"
                return

            if name == "":
                name = args.join(" ")
                
            ntshow(table, name)
        of "get", "g":
            if name == "" and args.len == 0:
                echo "Value missing: name"
                return

            if name == "":
                name = args.join(" ")
                
            ntget(table, name)
        of "getc", "gc", "getcode":
            if code == "" and args.len == 0:
                echo "Value missing: code"
                return

            if code == "":
                code = args.join(" ")
                
            ntgetc(table, code)
            
        of "getl", "gl", "getlang", "getlanguage":
            if lang == "" and args.len == 0:
                echo "Value missing: lang"
                return

            if lang == "":
                lang = args.join(" ")

            ntgetl(table, lang)
            
        of "create", "cr":
            if table == "" or table == "nt":
                echo "Can't create empty table."
            else:
                ntcreate(table)

            
db = open(getHomeDir()&"/nt.db", "", "", "")
spinLine()
db.close()     
