MODULES = argocd-helm aks/azure eks/aws openshift4/aws k3s/docker k3s/libvirt
MOD_REFS = $(addsuffix .adoc,$(addprefix docs/modules/ROOT/pages/references/terraform_modules/,$(MODULES)))

APPLICATIONS = $(shell ls argocd)
APP_REFS = $(addsuffix .adoc,$(addprefix docs/modules/ROOT/pages/references/applications/,$(APPLICATIONS)))
APP_BASE_REFS = $(addsuffix /REFERENCE.adoc,$(addprefix argocd/,$(APPLICATIONS)))

refs: mod_refs app_refs

mod_refs: $(MOD_REFS)

docs/modules/ROOT/pages/references/terraform_modules/%.adoc:
	mkdir -p $(shell dirname $@)
	terraform-docs asciidoc --header-from README.adoc modules/$* > $@

app_refs: $(APP_REFS)
app_base_refs: $(APP_BASE_REFS)

docs/modules/ROOT/pages/references/applications/%.adoc: argocd/%/REFERENCE.adoc
	-cat argocd/$*/README.adoc argocd/$*/REFERENCE.adoc > $@

argocd/%/REFERENCE.adoc:
	helm-docs --chart-search-root argocd/$* --dry-run | pandoc -o $@
	touch $@