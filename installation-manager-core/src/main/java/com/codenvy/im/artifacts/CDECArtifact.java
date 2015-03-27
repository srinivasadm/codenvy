/*
 * CODENVY CONFIDENTIAL
 * __________________
 *
 *  [2012] - [2015] Codenvy, S.A.
 *  All Rights Reserved.
 *
 * NOTICE:  All information contained herein is, and remains
 * the property of Codenvy S.A. and its suppliers,
 * if any.  The intellectual and technical concepts contained
 * herein are proprietary to Codenvy S.A.
 * and its suppliers and may be covered by U.S. and Foreign Patents,
 * patents in process, and are protected by trade secret or copyright law.
 * Dissemination of this information or reproduction of this material
 * is strictly forbidden unless prior written permission is obtained
 * from Codenvy S.A..
 */
package com.codenvy.im.artifacts;

import com.codenvy.im.artifacts.helper.CDECArtifactHelper;
import com.codenvy.im.artifacts.helper.CDECMultiServerHelper;
import com.codenvy.im.artifacts.helper.CDECSingleServerHelper;
import com.codenvy.im.backup.BackupConfig;
import com.codenvy.im.command.Command;
import com.codenvy.im.config.Config;
import com.codenvy.im.config.ConfigUtil;
import com.codenvy.im.install.InstallOptions;
import com.codenvy.im.install.InstallType;
import com.codenvy.im.utils.HttpTransport;
import com.codenvy.im.utils.Version;
import com.google.common.collect.ImmutableList;
import com.google.common.collect.ImmutableMap;
import com.google.inject.Inject;
import com.google.inject.Singleton;

import org.eclipse.che.api.core.rest.shared.dto.ApiInfo;

import javax.annotation.Nullable;
import java.io.IOException;
import java.nio.file.Path;
import java.util.List;
import java.util.Map;

import static com.codenvy.im.command.DetectInstallationTypeCommand.detectInstallationType;
import static com.codenvy.im.utils.Commons.createDtoFromJson;
import static java.lang.String.format;

/**
 * @author Anatoliy Bazko
 * @author Dmytro Nochevnov
 */
@Singleton
public class CDECArtifact extends AbstractArtifact {
    private final Map<InstallType, CDECArtifactHelper> helpers = ImmutableMap.of
            (
                    InstallType.CODENVY_SINGLE_SERVER, new CDECSingleServerHelper(this),
                    InstallType.CODENVY_MULTI_SERVER, new CDECMultiServerHelper(this)
            );

    public static final String NAME = "codenvy";

    private final HttpTransport transport;
    private final ConfigUtil configUtil;

    @Inject
    public CDECArtifact(HttpTransport transport, ConfigUtil configUtil) {
        super(NAME);
        this.transport = transport;
        this.configUtil = configUtil;
    }

    /** {@inheritDoc} */
    @Override
    public Version getInstalledVersion() throws IOException {
        Config config;
        try {
            config = configUtil.loadInstalledCodenvyConfig(getInstalledType());
            if (config == null) {
                return null;
            }
        } catch (IOException e) {
            return null;
        }

        try {
            return getInstalledVersion(config.getHostUrl());
        } catch (IOException e) {
            return null;
        }
    }

    @Nullable
    protected Version getInstalledVersion(String hostName) throws IOException {
        String response;
        try {
            String checkServiceUrl = format("http://%s/api/", hostName);
            response = transport.doOption(checkServiceUrl, null);
        } catch (IOException e) {
            return null;
        }

        ApiInfo apiInfo = createDtoFromJson(response, ApiInfo.class);
        if (apiInfo == null) {
            return null;
        }

        if (apiInfo.getIdeVersion() == null
            && apiInfo.getImplementationVersion() != null
            && apiInfo.getImplementationVersion().equals("0.26.0")) {
            return Version.valueOf("3.1.0"); // Old ide doesn't contain Ide Version property
        }

        return Version.valueOf(apiInfo.getIdeVersion());
    }

    /** {@inheritDoc} */
    @Override
    public int getPriority() {
        return 10;
    }

    /** {@inheritDoc} */
    @Override
    public List<String> getUpdateInfo(InstallOptions installOptions) throws IOException {
        if (installOptions.getInstallType() != getInstalledType()) {
            throw new IllegalArgumentException("Only update to the Codenvy of the same installation type is supported");
        }

        return ImmutableList.of("Unzip Codenvy binaries to /tmp/codenvy",
                                "Configure Codenvy",
                                "Patch resources",
                                "Move Codenvy binaries to /etc/puppet",
                                "Update Codenvy");
    }

    /**
     * {@inheritDoc}
     *
     * @throws IOException
     */
    @Override
    public Command getUpdateCommand(Version versionToUpdate, Path pathToBinaries, InstallOptions installOptions)
            throws IOException, IllegalArgumentException {
        if (installOptions.getInstallType() != getInstalledType()) {
            throw new IllegalArgumentException("Only update to the Codenvy of the same installation type is supported");
        }

        return getHelper(installOptions.getInstallType())
                .getUpdateCommand(versionToUpdate, pathToBinaries, installOptions);
    }

    @Override
    public List<String> getInstallInfo(InstallOptions installOptions) throws IOException {
        return getHelper(installOptions.getInstallType())
                .getInstallInfo(installOptions);
    }

    /** {@inheritDoc} */
    @Override
    public Command getInstallCommand(final Version versionToInstall,
                                     final Path pathToBinaries,
                                     final InstallOptions installOptions) throws IOException {

        return getHelper(installOptions.getInstallType())
                .getInstallCommand(versionToInstall, pathToBinaries, installOptions);
    }

    /** {@inheritDoc} */
    public InstallType getInstalledType() throws IOException {
        return detectInstallationType();
    }

    /** {@inheritDoc} */
    @Override
    public Command getBackupCommand(BackupConfig backupConfig, ConfigUtil codenvyConfigUtil) throws IOException {
        CDECArtifactHelper helper = getHelper(getInstalledType());
        return helper.getBackupCommand(backupConfig, codenvyConfigUtil);
    }

    /** {@inheritDoc} */
    @Override
    public Command getRestoreCommand(BackupConfig backupConfig, ConfigUtil codenvyConfigUtil) throws IOException {
        CDECArtifactHelper helper = getHelper(getInstalledType());
        return helper.getRestoreCommand(backupConfig, codenvyConfigUtil);
    }

    protected CDECArtifactHelper getHelper(InstallType type) {
        return helpers.get(type);
    }


}
