package main

import (
	"bufio"
	"database/sql"
	"errors"
	"flag"
	"fmt"
	_ "github.com/bmizerany/pq"
	"io/ioutil"
	"log"
	"os"
	"strconv"
	"strings"
	"time"
)

const VERSION = 1.0

func main() {
	// Get the environment, possible values: development, production, test
	var (
		environment string
		genotype_id string
		temp_file   string
	)
	flag.StringVar(&environment, "environment", "development", "Name of the Rails environment this worker runs in.")
	flag.StringVar(&genotype_id, "genotype_id", "-1", "ID of the genotype we're parsing")
	flag.StringVar(&temp_file, "temp_file", "xxx", "Path of the file we're parsing")
	version := flag.Bool("v", false, "prints current version")

	flag.Parse()

	if *version {
		fmt.Println("Version is:", VERSION)
		os.Exit(0)
	}

	// A map to switch names for known SNPs
	db_snp_snps := map[string]string{"MT-T3027C": "rs199838004", "MT-T4336C": "rs41456348", "MT-G4580A": "rs28357975", "MT-T5004C": "rs41419549", "MT-C5178a": "rs28357984", "MT-A5390G": "rs41333444", "MT-C6371T": "rs41366755", "MT-G8697A": "rs28358886", "MT-G9477A": "rs2853825", "MT-G10310A": "rs41467651", "MT-A10550G": "rs28358280", "MT-C10873T": "rs2857284", "MT-C11332T": "rs55714831", "MT-A11947G": "rs28359168", "MT-A12308G": "rs2853498", "MT-A12612G": "rs28359172", "MT-T14318C": "rs28357675", "MT-T14766C": "rs3135031", "MT-T14783C": "rs28357680"}

	// TODO: Make file-opening less error-prone
	// Initialize logger
	logFile, err := os.Create("../../log/goworker.log")
	if err != nil {
		log.Println(err)
	}
	log := log.New(logFile, "goworker-", 0)
	log.Println("Started worker-pool")
	// Get username, password for database from database.yml
	configFile := "../../config/database.yml"

	// Read all lines from the configFile into a slice (list) of type []byte
	config, err := ioutil.ReadFile(configFile)
	if err != nil {
		log.Println(err)
		os.Exit(1)
	}

	// TODO: parsing the db-config like this is ugly. Unfortunately, all YAML packages for Go are ugly, too.
	// As an upside, all of the following is run only once.
	configs := strings.Split(string(config), "\n")
	inside := false
	database_name := "snpr_development"
	username := ""
	password := ""
	port := "5432"
	max_conns := 25
	for _, line := range configs {
		// Are we in the right environment?
		if line == environment+":" {
			// Flip the switch so that the next field containining "database" is the name of our database
			inside = true
		}
		if strings.Contains(line, "database:") && inside {
			database_name = strings.Trim(strings.Split(line, ": ")[1], " ")
			inside = false
		}
		if strings.Contains(line, "port:") {
			port = strings.Trim(strings.Split(line, ": ")[1], " ")
		}
		if strings.Contains(line, "username:") {
			username = strings.Trim(strings.Split(line, ": ")[1], " ")
		}
		if strings.Contains(line, "password:") {
			password = strings.Trim(strings.Split(line, ": ")[1], " ")
		}
		if strings.Contains(line, "pool:") {
			max_conns, err = strconv.Atoi(strings.Trim(strings.Split(line, ": ")[1], " "))
			if err != nil {
				log.Println(err)
				os.Exit(1)
			}
		}
	}
	// Connect to database
	connection_string := "user=" + username + " password=" + password + " dbname=" + database_name + " sslmode=disable port=" + port
	db, err := sql.Open("postgres", connection_string)
	if err != nil {
		log.Println(err)
		os.Exit(1)
	}
	db.SetMaxIdleConns(max_conns)

	// Now load the known SNPs
	known_snps := make(map[string]bool) // There is no set-type, so this is a workaround
	rows, err := db.Query("SELECT name FROM snps;")
	if err != nil {
		log.Println(err)
		os.Exit(1)
	}
	for rows.Next() {
		var name string
		if err := rows.Scan(&name); err != nil {
			log.Println(err)
			os.Exit(1)
		}
		known_snps[name] = true
	}

	// The arguments are:

	// Get the genotype from the database using @genotype.id
	// We're only interested in genotype.filetype and genotype.user_id
	var (
		filetype string
		user_id  string
	)

	fmt.Println(genotype_id)
	query_string := "SELECT genotypes.filetype, genotypes.user_id FROM genotypes WHERE genotypes.id = " + genotype_id + " LIMIT 1;"
	rows, err = db.Query(query_string)
	if err != nil {
		log.Println(err)
		os.Exit(1)
	}

	for rows.Next() {
		if err := rows.Scan(&filetype, &user_id); err != nil {
			log.Println(err)
			os.Exit(1)
		}
	}
	if err := rows.Err(); err != nil {
		log.Println(err)
		os.Exit(1)
	}

	// Now load the known user-snps
	known_user_snps := make(map[string]bool)
	rows, err = db.Query("SELECT user_snps.snp_name FROM user_snps WHERE user_snps.user_id = " + user_id + ";")
	if err != nil {
		log.Println(err)
		os.Exit(1)
	}
	for rows.Next() {
		var snp_name string
		if err := rows.Scan(&snp_name); err != nil {
			log.Println(err)
			os.Exit(1)
		}
		known_user_snps[snp_name] = true
	}

	if err := rows.Err(); err != nil {
		log.Println(err)
		os.Exit(1)
	}

	// Now, finally, open the single_temp_file and create userSNPs
	log.Println("Started work on " + temp_file)
	var file *os.File
	if file, err = os.Open(temp_file); err != nil {
		log.Println(err)
		os.Exit(1)
	}
	defer file.Close()

	scanner := bufio.NewScanner(file)
	// Guess the filetype of the genotyping. If it's different than the "official" filetype, change the filetype in the database.
	var actual_filetype string
	scanner.Scan()
	first_line := scanner.Text()
	if strings.HasPrefix(first_line, "# This data file generated by 23andMe") {
		actual_filetype = "23andme"
	} else if strings.HasPrefix(first_line, "Name,Variation,Chromosome") {
		actual_filetype = "decodeme"
	} else if strings.HasPrefix(first_line, "##fileformat=VCFv4") {
		actual_filetype = "23andme-exome-vcf"
	} else if strings.HasPrefix(first_line, "#AncestryDNA raw") {
		actual_filetype = "ancestry"
	} else if strings.HasPrefix(first_line, "RSID,CHROMOSOME,") {
		actual_filetype = "ftdna-illumina"
	} else if strings.HasPrefix(first_line, "rs2131925") {
		actual_filetype = "IYG"
	}
	// In all other cases, actual_filetype stays "", then trust the user's setting
	// Some users take unorthodox genotypings and write parsers to change their formatting to 23andme's (or others)
	// Other users just break the whole thing by uploading something broken
	if actual_filetype != "" && actual_filetype != filetype {
		// Update the field in the database to actual_filetype, and use the proper filetype
		log.Println("Genotyping " + genotype_id + " is supposed to have type " + filetype + " , but it's actually " + actual_filetype)
		// Notice the difference here - using Exec instead of Query, we don't need any rows returned
		_, err = db.Exec("UPDATE genotypes SET filetype = " + actual_filetype + " WHERE id = " + genotype_id + ";")
		if err != nil {
			log.Println("Couldn't change the filetype of " + genotype_id + ", reason:")
			log.Println(err)
			os.Exit(1)
		}
		filetype = actual_filetype
	}

	// Turn off AUTOCOMMIT by using BEGIN / INSERTs / COMMIT
	// More tips at http://www.postgresql.org/docs/current/interactive/populate.html,
	// TODO: Implement more improvements, maybe use PREPARE or even just COPY?
	db.Exec("BEGIN")

	// Reset the scanner to the very first line, for example, IYG has already data in the first line
	scanner = bufio.NewScanner(file)
	for scanner.Scan() {
		line := scanner.Text()
		if strings.HasPrefix(line, "#") {
			// Skip comments
			continue
		}
		line = strings.ToLower(strings.Trim(line, "\n"))
		// Fix the linelist for all different filetypes
		var linelist []string
		if filetype == "23andme" {
			// Nothing much to do for 23andme
			linelist = strings.Split(line, "\t")
		} else if filetype == "ancestry" {
			linelist := strings.Split(line, "\t")
			if linelist[0] == "rsid" {
				continue
			}
			linelist = []string{linelist[0], linelist[1], linelist[3], linelist[4] + linelist[5]}
		} else if filetype == "decodeme" {
			linelist := strings.Split(line, ",")
			if linelist[0] == "Name" {
				// skip header
				continue
			}
			linelist = []string{linelist[0], linelist[2], linelist[3], linelist[5]}
		} else if filetype == "ftdna-illumina" {
			// Remove "
			line = strings.Replace(line, `"`, "", -1) // Backticks are needed here.
			linelist := strings.Split(line, ",")
			if linelist[0] == "RSID" {
				// skip header
				continue
			}
			// Interestingly, from here on ftdna has the same format as 23andme
		} else if filetype == "23andme-exome-vcf" {
			// This is a valid VCF so a bit more work is needed
			linelist := strings.Split(line, "\t")
			format_array := strings.Split(linelist[8], ":")
			genotype_index := -1
			for index, element := range format_array {
				if element == "GT" {
					genotype_index = index
					break
				}
			}
			non_genotype_parsed := strings.Split(strings.Split(linelist[9], ":")[genotype_index], "/")
			genotype_parsed := ""
			for _, allele := range non_genotype_parsed {
				if allele == "0" {
					genotype_parsed = genotype_parsed + linelist[3]
				} else if allele == "1" {
					genotype_parsed = genotype_parsed + linelist[4]
				}
			}
			linelist = []string{strings.ToLower(linelist[2]), linelist[0], linelist[1], strings.ToUpper(genotype_parsed)}

		} else if filetype == "IYG" {
			linelist := strings.Split(line, "\t")
			name := linelist[0]
			// Have to get the position from the name
			// TODO: This is an ugly hack - first, replace all runes
			// which are letters by X, then replace that X by nothing
			replace_letters := func(r rune) rune {
				switch {
				case r >= 'A' && r <= 'Z':
					return 'X'
				case r >= 'a' && r <= 'z':
					return 'X'
				}
				return r
			}
			position := strings.Map(replace_letters, name)
			position = strings.Replace(position, "X", "", -1)
			if strings.HasPrefix(name, "MT") {
				// Check whether we have to replace the name with the correct rs ID
				new_name, ok := db_snp_snps[name]
				if ok {
					name = new_name
				}
				linelist = []string{name, "MT", position, linelist[1]}
			} else {
				linelist = []string{linelist[0], "1", "1", linelist[1]}
			}

		} else {
			log.Println("unknown filetype", filetype)
			err := errors.New("Unknown filetype in parsing")
			log.Println(err)
			os.Exit(1)
		}

		// Example:
		// ["rs123", "11", "421412", "aa"]
		snp_name := linelist[0]
		chromosome := strings.ToUpper(linelist[1]) // mt -> MT
		position := linelist[2]
		allele := strings.ToUpper(linelist[3])
		// Is this a known SNP?
		_, ok := known_snps[snp_name]
		if !ok {
			// Create a new SNP
			time := time.Now().UTC().Format(time.RFC3339)
			// possibly TODO: Initialize the genotype frequencies, allele frequencies
			insertion_string := "INSERT INTO snps (name, chromosome, position, ranking, created_at, updated_at) VALUES ('" + snp_name + "','" + chromosome + "','" + position + "','0','" + time + "', '" + time + "');"
			_, err := db.Exec(insertion_string)
			if err != nil {
				log.Println(err)
				os.Exit(1)
			}
		}
		// Is this a known userSNP?
		_, ok = known_user_snps[snp_name]
		if !ok {
			// Create a new userSNP
			time := time.Now().Format(time.RFC3339)
			// snp_id is deprecated, just use snp_name
			user_snp_insertion_string := "INSERT INTO user_snps (local_genotype, genotype_id, user_id, created_at, updated_at, snp_name) VALUES ('" + allele + "','" + genotype_id + "','" + user_id + "','" + time + "','" + time + "','" + snp_name + "');"
			_, err := db.Exec(user_snp_insertion_string)
			if err != nil {
				log.Println(err)
				os.Exit(1)
			}
		} else {
			log.Println("User-SNP " + snp_name + " with allele " + allele + " already exists")
		}

	} // End of file-parsing
	log.Println("Running COMMIT")
	_, err = db.Exec("COMMIT")
	if err != nil {
		log.Println(err)
		os.Exit(1)
	}
	// Update our indexes
	// Both of these should only take a few seconds
	log.Println("VACUUMing...")
	db.Exec("VACUUM ANALYZE snps")
	db.Exec("VACUUM ANALYZE user_snps")
	log.Println("Done!")
	os.Exit(0)
}
