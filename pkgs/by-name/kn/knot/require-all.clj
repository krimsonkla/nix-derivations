(require '[babashka.fs :as fs] '[clojure.string :as str])
(let [root (first *command-line-args*)
      files (sort (map str (fs/glob root "**/*.clj")))
      nses (map (fn [f] (-> (str (fs/relativize root f)) (str/replace #"\.clj$" "") (str/replace "/" ".") (str/replace "_" "-") symbol)) files)]
  (doseq [n nses] (require n))
  (println (str "namespaces required: " (count nses))))
