;; Require the entry namespaces named on the command line, and with each one
;; its whole transitive closure: a namespace anywhere in that closure needing
;; a library this babashka does not bundle fails here, by that library's name,
;; instead of later inside a subcommand. knot's require-all.clj globs src/
;; instead, which is right for a tree with no JVM-only code and wrong here:
;; clj-surgeon's mcp_* modules need clojure-mcp, jetty and nrepl and do not
;; load under babashka by design.
;;
;; No argument is a failure, never a vacuous pass: a caller whose expansion
;; broke would otherwise require nothing and exit 0.
(let [nses (map symbol *command-line-args*)]
  (when (empty? nses)
    (binding [*out* *err*]
      (println "require-main.clj: no entry namespace given"))
    (System/exit 2))
  (doseq [n nses] (require n))
  (println (str "entry namespaces required: " (count nses))))
